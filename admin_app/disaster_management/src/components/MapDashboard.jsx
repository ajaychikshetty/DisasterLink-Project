// src/components/MapDashboard.jsx
import React, { useState, useEffect, useMemo, useRef } from "react";
import {
  MapContainer,
  TileLayer,
  Marker,
  Popup,
  GeoJSON,
  useMap,
  Rectangle,
  Polyline,
  useMapEvents,
} from "react-leaflet";
import L from "leaflet";
import "leaflet.heat";
import { SlidersHorizontal } from "lucide-react";
import booleanPointInPolygon from "@turf/boolean-point-in-polygon";
import { point as turfPoint } from "@turf/helpers";

import { getShelters } from "../services/shelterService";
import {
  getRescueTeams,
  assignTeam,
  unassignTeam,
} from "../services/rescueOpsService";
import { getVictims } from "../services/victimsService";
import { sendDisasterAlert } from "../services/smsService";

// --- Fix Leaflet Icon Path Issue ---
import markerShadow from "leaflet/dist/images/marker-shadow.png";
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  shadowUrl: markerShadow,
});

// Helper: small SVG marker
const createSvgIcon = (fillColor = "#999", size = 28) => {
  const svg = encodeURIComponent(`
    <svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 25 41">
      <path d="M12.5 0C7 0 2.8 4.3 2.8 9.6c0 6.9 9.7 21.4 9.7 21.4s9.7-14.5 9.7-21.4C22.2 4.3 18 0 12.5 0z" fill="${fillColor}" stroke="#00000033" stroke-width="0.6"/>
      <circle cx="12.5" cy="10" r="4.2" fill="white" opacity="0.9"/>
      <circle cx="12.5" cy="10" r="2.2" fill="${fillColor}"/>
    </svg>
  `);
  return new L.Icon({
    iconUrl: `data:image/svg+xml;charset=utf-8,${svg}`,
    iconSize: [25, 41],
    iconAnchor: [12, 41],
    popupAnchor: [1, -34],
    shadowUrl: markerShadow,
    shadowSize: [41, 41],
  });
};

// Icons
const ICONS = {
  lightGrey: createSvgIcon("#7fe81dff"), // team free 
  darkGrey: createSvgIcon("#e419ebff"),
  black: createSvgIcon("#fae20aff"),
  victim: createSvgIcon("#ff0000ff"),
  shelter: createSvgIcon("#370aeaff"),
};

// Choropleth Layer (Unchanged)
const ChoroplethLayer = ({ victimPoints, onWardAlert, assigningTeamId }) => {
  const [geoData, setGeoData] = useState(null);
  const victimPointsRef = useRef(victimPoints);

  useEffect(() => {
    victimPointsRef.current = victimPoints;
  }, [victimPoints]);

  useEffect(() => {
    fetch("http://localhost:5000/api/map/mumbai-map")
      .then((res) => res.json())
      .then((data) => setGeoData(data))
      .catch((err) => {
        console.error("Failed to load ward geojson:", err);
        setGeoData(null);
      });
  }, []);

  const wardDensity = useMemo(() => {
    if (!geoData) return {};
    const density = {};
    geoData.features.forEach((_, i) => (density[i] = 0));

    if (!Array.isArray(victimPoints)) return density;
    victimPoints.forEach((v) => {
      if (typeof v.latitude !== "number" || typeof v.longitude !== "number") return;
      const pt = turfPoint([v.longitude, v.latitude]);
      geoData.features.forEach((f, i) => {
        try {
          if (booleanPointInPolygon(pt, f)) density[i] += 1;
        } catch {}
      });
    });
    return density;
  }, [geoData, victimPoints]);

  const getColor = (d) =>
    d > 50 ? "#4a0c04" :
    d > 25 ? "#800026" :
    d > 10 ? "#BD0026" :
    d > 5  ? "#E31A1C" :
    d > 1  ? "#FC4E2A" :
    d > 0  ? "#FD8D3C" :
             "#FFEDA0";

  if (!geoData) return null;

  return (
    <GeoJSON
      key={assigningTeamId ? 'assigning' : 'interactive'}
      data={geoData}
      style={(feature) => {
        const idx = geoData.features.indexOf(feature);
        const val = wardDensity[idx] || 0;
        return {
          fillColor: getColor(val),
          weight: 1,
          opacity: 1,
          color: "black",
          fillOpacity: 0.7,
        };
      }}
      onEachFeature={(feature, layer) => {
        layer.off();
        if (assigningTeamId) {
          return;
        }
        
        const idx = geoData.features.indexOf(feature);
        const count = wardDensity[idx] || 0;
        const wardName = feature.properties?.name || "Unknown";

        const popupContent = `
          <div>
            <b>Ward:</b> ${wardName}<br/>
            <b>Victims:</b> ${count}<br/>
            <small style="color: #555; margin-top: 5px; display: block;">
              Double-click the ward to send an alert to this area.
            </small>
          </div>
        `;
        layer.bindPopup(popupContent);

        layer.on("dblclick", (e) => {
          L.DomEvent.stopPropagation(e);
          const usersInside = victimPointsRef.current.filter((v) => {
            if (typeof v.latitude !== "number" || typeof v.longitude !== "number") return false;
            const pt = turfPoint([v.longitude, v.latitude]);
            try {
              return booleanPointInPolygon(pt, feature);
            } catch {
              return false;
            }
          });
          onWardAlert(wardName, usersInside);
        });
      }}
    />
  );
};

// --- Map Data Loader (Unchanged) ---
const MapDataLoader = ({ setMapData }) => {
  const fetchData = () => {
    Promise.allSettled([getShelters(), getRescueTeams(), getVictims()])
      .then((results) => {
        const shelters = results[0].status === "fulfilled" ? results[0].value : [];
        const teams = results[1].status === "fulfilled" ? results[1].value : [];
        const victims = results[2].status === "fulfilled" ? results[2].value : [];

        const transformed = transformAll(shelters, teams, victims);
        setMapData(transformed);
      });
  };

  useEffect(() => { fetchData(); }, []);
  return null;
};

// --- Flexible Lat/Lng Extractor (Unchanged) ---
const extractLatLngFromLocation = (location) => {
  if (!location) return null;
  const num = (val) => {
    const n = Number(val);
    return isNaN(n) ? null : n;
  };
  if ("latitude" in location && "longitude" in location) {
    return { lat: num(location.latitude), lng: num(location.longitude) };
  }
  if ("lat" in location && "lng" in location) {
    return { lat: num(location.lat), lng: num(location.lng) };
  }
  if ("lat" in location && ("lon" in location || "long" in location)) {
    return { lat: num(location.lat), lng: num(location.lon ?? location.long) };
  }
  if (Array.isArray(location) && location.length > 0) {
    return extractLatLngFromLocation(location[0]);
  }
  return null;
};

// --- Transformer (Unchanged) ---
const transformAll = (shelters = [], teams = [], victims = []) => {
  const transformedShelters = shelters.map((s) => {
    const loc = extractLatLngFromLocation(s);
    return {
      id: s.id || s._id || s.shelterId || s.name,
      name: s.name || s.title || "Shelter",
      lat: loc?.lat,
      lng: loc?.lng,
      totalCapacity: s.totalCapacity ?? s.capacity ?? s.maxCapacity ?? null,
      rescuedCount: s.rescuedMembers?.length ?? s.currentOccupancy ?? s.rescuedCount ?? 0,
    };
  });

  const transformedTeams = teams.map((t) => {
    const leaderLoc = extractLatLngFromLocation(t.leader ?? {});
    return {
      id: t.teamId || t.id || t._id || t.teamName,
      name: t.teamName || t.name || "Rescue Team",
      leader: {
        id: (t.leader && t.leader.id) || t.leaderId || "unknown",
        name: (t.leader && t.leader.name) || (t.leader && t.leaderId) || "Leader",
        latitude: leaderLoc?.lat ?? null,
        longitude: leaderLoc?.lng ?? null,
      },
      status: t.status || "Free",
      assignedLatitude: t.assignedLatitude ?? null,
      assignedLongitude: t.assignedLongitude ?? null,
      members: t.members || {},
    };
  });

  const transformedVictims = (victims || []).map((v) => {
    const loc = extractLatLngFromLocation(v);
    if (!loc?.lat || !loc?.lng) return null;
    return {
      authId: v.authId,
      name: v.name,
      gender: v.gender,
      dateOfBirth: v.dateOfBirth,
      bloodGroup: v.bloodGroup,
      city: v.city,
      phoneNumber: v.phoneNumber,
      latitude: loc.lat,
      longitude: loc.lng,
      isActive: v.isActive,
      createdAt: v.createdAt,
      updatedAt: v.updatedAt,
    };
  }).filter(Boolean);

  return { shelters: transformedShelters, rescueTeams: transformedTeams, victims: transformedVictims };
};

// --- Rectangle Draw Component (Unchanged) ---
const RectangleDraw = ({ active, onCreated, onCancelled }) => {
  const map = useMap();
  const drawState = useRef({
    drawing: false, startLatLng: null, layer: null,
    moveHandler: null, upHandler: null, downHandler: null,
  });

  useEffect(() => {
    if (!active) return;
    const ds = drawState.current;
    if (map.dragging && map.dragging.enabled()) map.dragging.disable();
    map.getContainer().style.cursor = "crosshair";

    ds.downHandler = (e) => {
      ds.drawing = true;
      ds.startLatLng = e.latlng;
      ds.layer = L.rectangle([ds.startLatLng, ds.startLatLng], { color: "blue", weight: 1, fillOpacity: 0.1 }).addTo(map);
    };
    ds.moveHandler = (e) => {
      if (!ds.drawing || !ds.layer) return;
      const bounds = L.latLngBounds(ds.startLatLng, e.latlng);
      ds.layer.setBounds(bounds);
    };
    ds.upHandler = (e) => {
      if (!ds.drawing) return;
      ds.drawing = false;
      const bounds = ds.layer.getBounds();
      cleanup();
      const boundsArray = [
        [bounds.getSouthWest().lat, bounds.getSouthWest().lng],
        [bounds.getNorthEast().lat, bounds.getNorthEast().lng],
      ];
      onCreated(boundsArray, ds.layer);
    };

    const cleanup = () => {
      map.getContainer().style.cursor = "";
      if (map.dragging && !map.dragging.enabled()) map.dragging.enable();
      map.off("mousedown", ds.downHandler);
      map.off("mousemove", ds.moveHandler);
      map.off("mouseup", ds.upHandler);
    };

    map.on("mousedown", ds.downHandler);
    map.on("mousemove", ds.moveHandler);
    map.on("mouseup", ds.upHandler);

    const escHandler = (ev) => {
      if (ev.key === "Escape") {
        if (ds.layer) {
          map.removeLayer(ds.layer);
          ds.layer = null;
        }
        cleanup();
        onCancelled?.();
      }
    };
    window.addEventListener("keydown", escHandler);

    return () => {
      window.removeEventListener("keydown", escHandler);
      cleanup();
    };
  }, [active, map, onCreated, onCancelled]);
  return null;
};

// --- Map Click Assign Handler (Unchanged) ---
const AssignClickHandler = ({ assigningTeamId, onMapClickAssign, onCancel }) => {
  useMapEvents({
    click(e) {
      if (!assigningTeamId) return;
      L.DomEvent.stopPropagation(e);
      onMapClickAssign(assigningTeamId, e.latlng);
    },
    keydown(e) {
      if (e.originalEvent && e.originalEvent.key === "Escape") {
        onCancel();
      }
    },
  });
  return null;
};

// --- Main Dashboard ---
const MapDashboard = () => {
  const [mapData, setMapData] = useState({ victims: [], rescueTeams: [], shelters: [] });
  const [filters, setFilters] = useState({ victims: true, rescueTeams: true, shelters: true, density: true });
  const mapRef = useRef(null);
  const initialPosition = [19.076, 72.8777];

  const [teamsState, setTeamsState] = useState([]);
  useEffect(() => { setTeamsState(mapData.rescueTeams || []); }, [mapData.rescueTeams]);

  const [assigningTeamId, setAssigningTeamId] = useState(null);
  const [isDrawingActive, setIsDrawingActive] = useState(false);
  const [previewTeam, setPreviewTeam] = useState(null);
  const previewMarkerRef = useRef(null);

  useEffect(() => {
    if (!teamsState.find(t => t.id === assigningTeamId)) setAssigningTeamId(null);
  }, [teamsState, assigningTeamId]);
  
  // When filters change, if rescueTeams are hidden, clear the preview
  useEffect(() => {
    if (!filters.rescueTeams) {
      setPreviewTeam(null);
    }
  }, [filters.rescueTeams]);

  const handleFilterChange = (e) => {
    const { name, checked } = e.target;
    setFilters((prev) => ({ ...prev, [name]: checked }));
  };

  const startAssigning = (teamId) => {
    setAssigningTeamId(teamId);
    try { window?.document?.activeElement?.blur?.(); } catch {}
  };

  const cancelAssigning = () => setAssigningTeamId(null);

  const handleMapClickAssign = async (teamId, latlng) => {
    try {
      await assignTeam(teamId, latlng.lat, latlng.lng);
      setTeamsState((prev) =>
        prev.map((t) =>
          t.id === teamId
            ? { ...t, assignedLatitude: latlng.lat, assignedLongitude: latlng.lng }
            : t
        )
      );
      setAssigningTeamId(null);
      if (previewTeam?.id === teamId) setPreviewTeam(null);
    } catch (error) {
      console.error(`Failed to assign team ${teamId}:`, error);
      alert(`Error assigning team: ${error.message}`);
      setAssigningTeamId(null);
    }
  };

  const assignDirectly = async (teamId, lat, lng) => {
    try {
      await assignTeam(teamId, lat, lng);
      setTeamsState((prev) => prev.map((t) => (t.id === teamId ? { ...t, assignedLatitude: lat, assignedLongitude: lng } : t)));
      if (previewTeam?.id === teamId) setPreviewTeam(null);
    } catch (error) {
      console.error(`Failed to assign team ${teamId} directly:`, error);
      alert(`Error assigning team: ${error.message}`);
    }
  };

  const handleUnassignTeam = async (teamId) => {
    const originalTeamsState = [...teamsState];
    setTeamsState((prev) =>
      prev.map((t) =>
        t.id === teamId
          ? { ...t, assignedLatitude: null, assignedLongitude: null }
          : t
      )
    );

    try {
      await unassignTeam(teamId);
    } catch (error) {
      console.error("Failed to unassign team:", error);
      alert(`Error: ${error.message}`);
      setTeamsState(originalTeamsState);
    }
  };

  // --- Alert/Draw Handlers (Unchanged) ---
  const [alertBounds, setAlertBounds] = useState(null);
  const [alertLayerRef, setAlertLayerRef] = useState(null);
  const [showAlertModal, setShowAlertModal] = useState(false);
  const [alertMessage, setAlertMessage] = useState("");
  const [alertUsers, setAlertUsers] = useState([]);

  const handleRectangleCreated = (boundsArray, layer) => {
    setAlertBounds(boundsArray);
    setAlertLayerRef(layer || null);
    const bounds = L.latLngBounds(L.latLng(boundsArray[0][0], boundsArray[0][1]), L.latLng(boundsArray[1][0], boundsArray[1][1]));
    const usersInside = (mapData.victims || []).filter((v) => {
      if (typeof v.latitude !== "number" || typeof v.longitude !== "number") return false;
      return bounds.contains(L.latLng(v.latitude, v.longitude));
    });
    setAlertUsers(usersInside);
    setShowAlertModal(true);
    setIsDrawingActive(false);
  };

  const handleCancelDrawing = () => setIsDrawingActive(false);

  const handleSendAlert = async () => {
    if (!alertMessage.trim() || alertUsers.length === 0) return;
    const phoneNumbers = alertUsers.map(u => u.phoneNumber).filter(Boolean);
    if (phoneNumbers.length === 0) {
      alert("No valid phone numbers found for the selected victims.");
      return;
    }
    try {
      await sendDisasterAlert(alertMessage, phoneNumbers);
      alert(`Alert sent successfully to ${phoneNumbers.length} recipients.`);
      handleDiscardAlert();
    } catch (err) {
      console.error("Failed to send alert:", err);
      alert("An error occurred while sending the alert.");
    }
  };

  const handleDiscardAlert = () => {
    setShowAlertModal(false);
    setAlertMessage("");
    setAlertBounds(null);
    setAlertUsers([]);
    if (alertLayerRef?.remove) {
      try { alertLayerRef.remove(); } catch (e) {}
      setAlertLayerRef(null);
    }
  };

  useEffect(() => {
    if (!previewTeam || !mapRef.current) return;
    const coords = (previewTeam.leader && typeof previewTeam.leader.latitude === 'number' && typeof previewTeam.leader.longitude === 'number')
      ? [previewTeam.leader.latitude, previewTeam.leader.longitude]
      : initialPosition;
    try {
      mapRef.current.setView(coords, 14, { animate: true });
    } catch {}
    setTimeout(() => {
      try {
        if (previewMarkerRef.current && previewMarkerRef.current._map) {
          previewMarkerRef.current.openPopup();
        }
      } catch (e) {}
    }, 100);
  }, [previewTeam]);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Mumbai Disaster Map</h1>
          <p className="text-gray-400 mt-1">Ward density, rescue teams, shelters, and victims</p>
        </div>
      </div>

      <div className="flex gap-6">
        <div className="flex-1 bg-gray-800 rounded-xl overflow-hidden" style={{ height: "70vh" }}>
          <MapContainer
            center={initialPosition}
            zoom={12}
            style={{ height: "100%", width: "100%" }}
            whenCreated={(mapInstance) => { mapRef.current = mapInstance; }}
          >
            <TileLayer
              attribution="&copy; OpenStreetMap"
              url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
            />
            <MapDataLoader setMapData={setMapData} />
            {filters.density && (
              <ChoroplethLayer
                victimPoints={mapData.victims}
                assigningTeamId={assigningTeamId}
                onWardAlert={(wardName, usersInside) => {
                  setAlertBounds(null);
                  setAlertUsers(usersInside);
                  setShowAlertModal(true);
                }}
              />
            )}
            {isDrawingActive && (
              <RectangleDraw active={isDrawingActive} onCreated={handleRectangleCreated} onCancelled={handleCancelDrawing} />
            )}
            {alertBounds && <Rectangle bounds={alertBounds} pathOptions={{ color: "blue", weight: 2, dashArray: "4" }} />}

            {filters.victims && mapData.victims.map((v) =>
              v.latitude && v.longitude ? (
                <Marker key={v.authId} position={[v.latitude, v.longitude]} icon={ICONS.victim}>
                  <Popup><b>{v.name}</b><br/>Phone: {v.phoneNumber}<br/>Blood Group: {v.bloodGroup}</Popup>
                </Marker>
              ) : null
            )}

            {filters.shelters && mapData.shelters.map((s) =>
              s.lat && s.lng ? (
                <Marker key={s.id} position={[s.lat, s.lng]} icon={
                    new L.DivIcon({
                    html: `<div style="font-size: 2rem; color: #370aeaff; line-height: 1;"><span role="img" aria-label="house">🏠</span></div>`,
                    className: "",
                    iconSize: [32, 32],
                    iconAnchor: [16, 32],
                    popupAnchor: [0, -32],
                    })
                  }>
                    <Popup><b>{s.name}</b><br/>Capacity: {s.rescuedCount}/{s.totalCapacity ?? "?"}</Popup>
                  </Marker>
              ) : null
            )}

            {/* Rescue Teams */}
            {filters.rescueTeams && teamsState.map((team) => {
              const leaderLat = team.leader?.latitude;
              const leaderLng = team.leader?.longitude;
              const assignedLat = team.assignedLatitude;
              const assignedLng = team.assignedLongitude;
              const hasAssigned = typeof assignedLat === "number" && typeof assignedLng === "number";
              const leaderIcon = hasAssigned ? ICONS.darkGrey : ICONS.lightGrey;

              return (
                <React.Fragment key={`team-${team.id}`}>
                  {typeof leaderLat === "number" && typeof leaderLng === "number" && (
                    <Marker position={[leaderLat, leaderLng]} icon={leaderIcon}>
                      <Popup>
                        <div style={{ minWidth: 220 }}>
                          <b>{team.name}</b><br/>
                          <small>Leader: {team.leader?.name}</small><br/>
                          <small>Status: {team.status}</small>
                          <div className="mt-3 flex gap-2">
                            {!hasAssigned ? (
                              <button onClick={() => startAssigning(team.id)} className="px-2 py-1 bg-indigo-600 text-white rounded">
                                Assign Location
                              </button>
                            ) : (
                              <>
                                <button onClick={() => startAssigning(team.id)} className="px-2 py-1 bg-yellow-500 text-black rounded">
                                  Reassign
                                </button>
                                <button onClick={() => handleUnassignTeam(team.id)} className="px-2 py-1 bg-red-600 text-white rounded">
                                  Remove Assignment
                                </button>
                              </>
                            )}
                          </div>
                        </div>
                      </Popup>
                    </Marker>
                  )}

                  {hasAssigned && (
                    <>
                      <Marker position={[assignedLat, assignedLng]} icon={ICONS.black}>
                        <Popup>
                          <div style={{ minWidth: 180 }}>
                            <b>Assigned: {team.name}</b><br/>
                            <small>Assigned coords: {assignedLat.toFixed(5)}, {assignedLng.toFixed(5)}</small>
                            <div className="mt-2 flex gap-2">
                              {/* --- FIX 2: UNCOMMENTED THIS BUTTON --- */}
                              <button onClick={() => startAssigning(team.id)} className="px-2 py-1 bg-yellow-500 text-black rounded">
                                Move Assigned
                              </button>
                              <button onClick={() => handleUnassignTeam(team.id)} className="px-2 py-1 bg-red-600 text-white rounded">
                                Unassign
                              </button>
                            </div>
                          </div>
                        </Popup>
                      </Marker>
                      <Polyline positions={[[leaderLat, leaderLng], [assignedLat, assignedLng]]} pathOptions={{ color: "#222", weight: 2, opacity: 0.8, dashArray: "2" }} />
                    </>
                  )}
                </React.Fragment>
              );
            })}
            
            {/* --- FIX 1: ADDED filters.rescueTeams CONDITION HERE --- */}
            {/* Preview Marker */}
            {filters.rescueTeams && previewTeam && (
              <Marker
                ref={previewMarkerRef}
                position={
                  (previewTeam.leader && typeof previewTeam.leader.latitude === 'number' && typeof previewTeam.leader.longitude === 'number')
                    ? [previewTeam.leader.latitude, previewTeam.leader.longitude]
                    : initialPosition
                }
                icon={ICONS.lightGrey}
              >
                <Popup>
                  <div style={{ minWidth: 220 }}>
                    <b>{previewTeam.name}</b><br/>
                    <small>Leader: {previewTeam.leader?.name}</small>
                    <div className="mt-3 flex flex-col gap-2">
                      {(previewTeam.leader && typeof previewTeam.leader.latitude === 'number' && typeof previewTeam.leader.longitude === 'number') && (
                        <button
                          onClick={() => assignDirectly(previewTeam.id, previewTeam.leader.latitude, previewTeam.leader.longitude)}
                          className="px-2 py-1 bg-green-600 text-white rounded"
                        >
                          Assign to Leader Location
                        </button>
                      )}
                      <button onClick={() => startAssigning(previewTeam.id)} className="px-2 py-1 bg-indigo-600 text-white rounded">
                        Assign by Clicking on Map
                      </button>
                      <button onClick={() => setPreviewTeam(null)} className="px-2 py-1 bg-gray-300 rounded">
                        Close
                      </button>
                    </div>
                  </div>
                </Popup>
              </Marker>
            )}

            {assigningTeamId && (
              <AssignClickHandler
                assigningTeamId={assigningTeamId}
                onMapClickAssign={handleMapClickAssign}
                onCancel={cancelAssigning}
              />
            )}
          </MapContainer>

          {assigningTeamId && (
            <div style={{
              position: "absolute", left: 24, bottom: 24, zIndex: 1000,
              background: "rgba(17,24,39,0.92)", color: "white", padding: "10px 12px",
              borderRadius: 8, boxShadow: "0 6px 18px rgba(0,0,0,0.4)",
            }}>
              <div style={{ fontWeight: 600 }}>Assigning location</div>
              <div style={{ fontSize: 13, marginTop: 4 }}>Click anywhere on the map to assign. Press Esc or Cancel to abort.</div>
              <div style={{ marginTop: 8, display: "flex", gap: 8 }}>
                <button onClick={cancelAssigning} style={{ padding: "6px 8px", borderRadius: 6, background: "#ef4444", color: "white", border: "none" }}>Cancel</button>
              </div>
            </div>
          )}
        </div>

        <div className="w-64 bg-gray-900 rounded-xl p-4 border border-gray-700 h-[70vh] overflow-y-auto">
          <h3 className="text-lg font-semibold text-white mb-3 flex items-center gap-2">
            <SlidersHorizontal size={18} /> Map Filters
          </h3>
          <div className="space-y-3">
            {["victims", "rescueTeams", "shelters", "density"].map((f) => (
              <div key={f} className="flex items-center">
                <input
                  type="checkbox" id={f} name={f} checked={filters[f]} onChange={handleFilterChange}
                  className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-600 rounded bg-gray-800"
                />
                <label htmlFor={f} className="ml-3 text-sm font-medium text-gray-300 capitalize">
                  {f === "density" ? "Ward Density (Victims)" : f}
                </label>
              </div>
            ))}
          </div>

          <div className="mt-4 pt-4 border-t border-gray-700">
            <button
              className={`w-full px-3 py-2 rounded ${isDrawingActive ? "bg-yellow-500 text-black" : "bg-indigo-600 text-white"}`}
              onClick={() => setIsDrawingActive((s) => !s)}
            >
              {isDrawingActive ? "Cancel Alert Draw" : "Send Alert (draw area)"}
            </button>
            <p className="text-xs text-gray-400 mt-2">
              Click, then drag on the map to select an area for an alert.
            </p>
          </div>

          <div className="mt-6 border-t border-gray-700 pt-4">
            <h3 className="text-lg font-semibold text-white mb-3">Available Teams</h3>
            <div className="space-y-2 text-sm">
              {(() => {
                const availableTeams = teamsState.filter(team => team.assignedLatitude == null || team.assignedLongitude == null);
                if (availableTeams.length === 0) {
                  return <p className="text-gray-500">No teams available.</p>;
                }
                return availableTeams.map(team => (
                  <div
                    key={team.id}
                    className="p-2 bg-gray-800 rounded cursor-pointer hover:bg-gray-700"
                    onClick={() => {
                      if (filters.rescueTeams) { // Only allow preview if the filter is on
                        setPreviewTeam(team);
                      }
                    }}
                  >
                    <p className="font-bold text-white">{team.name}</p>
                    <p className="text-gray-400">Leader: {team.leader?.name}</p>
                    <div className="mt-1 text-xs text-gray-500">Click to preview & assign this team on the map.</div>
                  </div>
                ));
              })()}
            </div>
          </div>
        </div>
      </div>

      {showAlertModal && (
        <div className="fixed inset-0 z-[1000] flex items-center justify-center">
          <div className="absolute inset-0 bg-black/60" onClick={handleDiscardAlert}></div>
          <div className="relative bg-white rounded-lg w-[min(90%,420px)] p-4 z-10">
            <h3 className="text-lg font-semibold mb-2">Send Alert</h3>
            <p className="text-sm text-gray-600 mb-3">Victims found in area: <b>{alertUsers.length}</b></p>
            <textarea
              value={alertMessage}
              onChange={(e) => setAlertMessage(e.target.value)}
              placeholder="Type your alert message..."
              className="w-full p-2 border border-gray-300 rounded h-28 mb-3 resize-none"
            />
            <div className="flex justify-end gap-2">
              <button className="px-3 py-1 rounded bg-gray-300" onClick={handleDiscardAlert}>Discard</button>
              <button className={`px-3 py-1 rounded ${alertMessage.trim() ? "bg-blue-600 text-white" : "bg-blue-300 cursor-not-allowed"}`}
                onClick={handleSendAlert} disabled={!alertMessage.trim()}>
                Send
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default MapDashboard;