import React, { useState, useEffect, useMemo, useRef } from "react";
import {
  MapContainer,
  TileLayer,
  Marker,
  Popup,
  GeoJSON,
  useMap,
  Rectangle,
} from "react-leaflet";
import L from "leaflet";
import "leaflet.heat";
import { SlidersHorizontal } from "lucide-react";
import booleanPointInPolygon from "@turf/boolean-point-in-polygon";
import { point as turfPoint } from "@turf/helpers";

import { getShelters } from "../services/shelterService";
import { getRescueTeams } from "../services/rescueOpsService";
// Import the new alert service along with getMessages
import { getMessages } from "../services/messageService";
import { sendDisasterAlert } from "../services/smsService";

// --- Fix Leaflet Icon Path Issue ---
import markerIcon2x from "leaflet/dist/images/marker-icon-2x.png";
import markerIcon from "leaflet/dist/images/marker-icon.png";
import markerShadow from "leaflet/dist/images/marker-shadow.png";
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: markerIcon2x,
  iconUrl: markerIcon,
  shadowUrl: markerShadow,
});

// --- Custom Icons ---
const userIcon = new L.Icon({
  iconUrl:
    "https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-blue.png",
  shadowUrl: markerShadow,
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41],
});
const teamIcon = new L.Icon({
  iconUrl:
    "https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-red.png",
  shadowUrl: markerShadow,
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41],
});
const shelterIcon = new L.Icon({
  iconUrl:
    "https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-green.png",
  shadowUrl: markerShadow,
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41],
});

// --- Choropleth Layer ---
const ChoroplethLayer = ({ messagePoints, onWardAlert }) => {
  const [geoData, setGeoData] = useState(null);

  // FIX: Use a ref to hold the latest messagePoints to avoid stale closures in event handlers.
  const messagePointsRef = useRef(messagePoints);
  useEffect(() => {
    messagePointsRef.current = messagePoints;
  }, [messagePoints]);

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

    if (!Array.isArray(messagePoints)) return density;

    messagePoints.forEach((m) => {
      if (typeof m.lat !== "number" || typeof m.lng !== "number") return;
      const pt = turfPoint([m.lng, m.lat]);
      geoData.features.forEach((f, i) => {
        try {
          if (booleanPointInPolygon(pt, f)) density[i] += 1;
        } catch {}
      });
    });
    return density;
  }, [geoData, messagePoints]);

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
        const idx = geoData.features.indexOf(feature);
        const count = wardDensity[idx] || 0;
        const wardName = feature.properties?.name || "Unknown";

        const popupContent = `
          <div>
            <b>Ward:</b> ${wardName}<br/>
            <b>Messages:</b> ${count}<br/>
            <button id="alert-btn-${idx}" 
              style="margin-top:6px; padding:4px 8px; background:#2563eb; color:white; border:none; border-radius:4px; cursor:pointer;">
              Send Alert
            </button>
          </div>
        `;
        layer.bindPopup(popupContent);

        layer.on("popupopen", () => {
          const btn = document.getElementById(`alert-btn-${idx}`);
          if (btn) {
            btn.addEventListener("click", () => {
              // FIX: Use the ref to get the most up-to-date list of messages.
              const usersInside = messagePointsRef.current.filter((m) => {
                if (typeof m.lat !== "number" || typeof m.lng !== "number") return false;
                const pt = turfPoint([m.lng, m.lat]);
                try {
                  return booleanPointInPolygon(pt, feature);
                } catch {
                  return false;
                }
              });
              onWardAlert(wardName, usersInside);
              layer.closePopup();
            });
          }
        });
      }}
    />
  );
};

// --- Map Data Loader ---
const MapDataLoader = ({ setMapData }) => {
  const fetchData = () => {
    Promise.allSettled([getShelters(), getRescueTeams(), getMessages()])
      .then((results) => {
        const shelters = results[0].status === "fulfilled" ? results[0].value : [];
        const teams = results[1].status === "fulfilled" ? results[1].value : [];
        const messages = results[2].status === "fulfilled" ? results[2].value : [];

        const transformed = transformAll(shelters, teams, messages);
        setMapData(transformed);
      });
  };

  useEffect(() => { fetchData(); }, []);
  return null;
};

// --- Flexible Lat/Lng Extractor ---
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

// --- Transformer ---
const transformAll = (shelters = [], teams = [], messages = []) => {
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
    const loc = extractLatLngFromLocation(t.location || t.loc || {});
    return {
      id: t.teamId || t.id || t._id || t.teamName,
      name: t.teamName || t.name || "Rescue Team",
      leader: t.leader || t.teamLead || "N/A",
      status: t.status || "Free",
      lat: loc?.lat,
      lng: loc?.lng,
      members: t.members || [],
    };
  });

  const transformedMessages = (messages || [])
    .map((m) => {
      if (!m.location?.latitude || !m.location?.longitude) return null;
      return {
        id: m.Timestamp,
        text: m.Message || "",
        lat: m.location.latitude,
        lng: m.location.longitude,
        timestamp: m.Timestamp,
        sender: m.Sender, // This 'sender' key holds the phone number
      };
    })
    .filter(Boolean);

  return { shelters: transformedShelters, rescueTeams: transformedTeams, messages: transformedMessages };
};

// --- Drop Handler Hook ---
const MapDropHandler = ({ onDropTeam }) => {
  const map = useMap();

  useEffect(() => {
    const container = map.getContainer();
    const handleDragOver = (e) => e.preventDefault();
    const handleDrop = (e) => {
      e.preventDefault();
      const data = e.dataTransfer.getData("team");
      if (data) {
        const team = JSON.parse(data);
        const { lat, lng } = map.containerPointToLatLng([e.layerX, e.layerY]);
        onDropTeam(team, { lat, lng });
      }
    };
    container.addEventListener("dragover", handleDragOver);
    container.addEventListener("drop", handleDrop);
    return () => {
      container.removeEventListener("dragover", handleDragOver);
      container.removeEventListener("drop", handleDrop);
    };
  }, [map, onDropTeam]);

  return null;
};

// --- Rectangle Draw Component ---
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
      const boundsArray = [[bounds.getSouthWest().lat, bounds.getSouthWest().lng], [bounds.getNorthEast().lat, bounds.getNorthEast().lng]];
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
        if (ds.layer) { map.removeLayer(ds.layer); ds.layer = null; }
        cleanup();
        onCancelled?.();
      }
    };
    window.addEventListener("keydown", escHandler);
    return () => {
      window.removeEventListener("keydown", escHandler);
      map.getContainer().style.cursor = "";
      if (map.dragging && !map.dragging.enabled()) map.dragging.enable();
      map.off("mousedown", ds.downHandler);
      map.off("mousemove", ds.moveHandler);
      map.off("mouseup", ds.upHandler);
    };
  }, [active, map, onCreated, onCancelled]);

  return null;
};

// --- Main Dashboard ---
const MapDashboard = () => {
  const [mapData, setMapData] = useState({ messages: [], rescueTeams: [], shelters: [] });
  const [filters, setFilters] = useState({
    messages: true, rescueTeams: true, shelters: true, density: true,
  });
  const [droppedTeams, setDroppedTeams] = useState([]);
  const popupRefs = useRef({});
  const initialPosition = [19.076, 72.8777];

  const handleFilterChange = (e) => {
    const { name, checked } = e.target;
    setFilters((prev) => ({ ...prev, [name]: checked }));
  };
  const handleDropTeam = (team, coords) => {
    setDroppedTeams((prev) => {
      const newList = [...prev, { ...team, ...coords, placed: false, movable: false }];
      const idx = newList.length - 1;
      setTimeout(() => {
        if (popupRefs.current[idx]) {
          popupRefs.current[idx].openOn(popupRefs.current[idx]._map);
        }
      }, 100);
      return newList;
    });
  };
  const placeTeam = (idx) => {
    setDroppedTeams((prev) => prev.map((t, i) => i === idx ? { ...t, placed: true, movable: false } : t));
    console.log("✅ Team placed:", droppedTeams[idx]);
  };
  const discardTeam = (idx) => {
    console.log("✅ Team discarded:", droppedTeams[idx]);
    setDroppedTeams((prev) => prev.filter((_, i) => i !== idx));
  };
  const enableMove = (idx) => {
    setDroppedTeams((prev) => prev.map((t, i) => i === idx ? { ...t, movable: true, placed: false } : t));
  };
  const updateTeamPosition = (idx, newPos) => {
    const updated = droppedTeams.map((t, i) => i === idx ? { ...t, lat: newPos.lat, lng: newPos.lng } : t);
    setDroppedTeams(updated);
    console.log("♻️ Team moved:", updated[idx]);
  };

  const [isDrawingActive, setIsDrawingActive] = useState(false);
  const [alertBounds, setAlertBounds] = useState(null);
  const [alertLayerRef, setAlertLayerRef] = useState(null);
  const [showAlertModal, setShowAlertModal] = useState(false);
  const [alertMessage, setAlertMessage] = useState("");
  const [alertUsers, setAlertUsers] = useState([]);

  const handleRectangleCreated = (boundsArray, layer) => {
    setAlertBounds(boundsArray);
    setAlertLayerRef(layer || null);
    const bounds = L.latLngBounds(L.latLng(boundsArray[0][0], boundsArray[0][1]), L.latLng(boundsArray[1][0], boundsArray[1][1]));
    const usersInside = (mapData.messages || []).filter((m) => {
      if (typeof m.lat !== "number" || typeof m.lng !== "number") return false;
      return bounds.contains(L.latLng(m.lat, m.lng));
    });
    setAlertUsers(usersInside);
    setShowAlertModal(true);
    setIsDrawingActive(false);
  };
  const handleCancelDrawing = () => {
    setIsDrawingActive(false);
  };

  // UPDATED: Function to call the API service
  const handleSendAlert = async () => {
    if (!alertMessage.trim() || alertUsers.length === 0) {
      console.warn("Alert message is empty or no users are selected.");
      return;
    }

    // 1. Extract the list of sender phone numbers from the selected users
    const phoneNumbers = alertUsers.map(user => user.sender).filter(Boolean);

    if (phoneNumbers.length === 0) {
      console.warn("No valid sender phone numbers found for the selected users.");
      alert("Could not send alert: No valid recipients found.");
      return;
    }

    try {
      // 2. Call the new API service function
      console.log(`Sending alert "${alertMessage}" to ${phoneNumbers.length} numbers...`);
      const response = await sendDisasterAlert(alertMessage, phoneNumbers);
      console.log("✅ Alert sent successfully! API Response:", response);
      alert(`Alert successfully sent to ${response.results?.length || 0} numbers.`);

      // 3. Reset state only on successful API call
      setShowAlertModal(false);
      setAlertMessage("");
      setAlertBounds(null);
      setAlertUsers([]);
      if (alertLayerRef && alertLayerRef.remove) {
        try { alertLayerRef.remove(); } catch (e) {}
        setAlertLayerRef(null);
      }
    } catch (error) {
      // 4. Handle any errors from the API call
      console.error("❌ Failed to send alert:", error);
      alert(`Failed to send alert: ${error.message}`);
    }
  };

  const handleDiscardAlert = () => {
    setShowAlertModal(false);
    setAlertMessage("");
    setAlertBounds(null);
    setAlertUsers([]);
    if (alertLayerRef && alertLayerRef.remove) {
      try { alertLayerRef.remove(); } catch (e) {}
      setAlertLayerRef(null);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Mumbai Disaster Map</h1>
          <p className="text-gray-400 mt-1">
            Mumbai's Ward SOS Density, Rescue Teams, and Emergency Shelters
          </p>
        </div>
      </div>

      <div className="flex gap-6">
        <div className="flex-1 bg-gray-800 rounded-xl overflow-hidden" style={{ height: "70vh" }}>
          <MapContainer center={initialPosition} zoom={12} style={{ height: "100%", width: "100%" }}>
            <TileLayer
              attribution="&copy; OpenStreetMap"
              url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
            />
            <MapDataLoader setMapData={setMapData} />
            <MapDropHandler onDropTeam={handleDropTeam} />

            {filters.density && (
              <ChoroplethLayer
                messagePoints={mapData.messages}
                onWardAlert={(wardName, usersInside) => {
                  setAlertBounds(null);
                  setAlertUsers(usersInside);
                  setShowAlertModal(true);
                  console.log("✅ Ward alert triggered:", wardName, "Users:", usersInside.length);
                }}
              />
            )}

            {isDrawingActive && (
              <RectangleDraw
                active={isDrawingActive}
                onCreated={handleRectangleCreated}
                onCancelled={handleCancelDrawing}
              />
            )}
            {alertBounds && (
              <Rectangle
                bounds={alertBounds}
                pathOptions={{ color: "blue", weight: 2, dashArray: "4" }}
              />
            )}

            {filters.messages && mapData.messages.map((msg) =>
                msg.lat && msg.lng ? (
                  <Marker key={msg.id} position={[msg.lat, msg.lng]} icon={userIcon}>
                    <Popup>
                      <b>Message</b>
                      <div className="mt-1">{msg.text || "(no text)"}</div>
                      <div className="mt-2 text-xs text-gray-400">From: {msg.sender || "unknown"}</div>
                      <div className="text-xs text-gray-400">Time: {msg.timestamp || "-"}</div>
                    </Popup>
                  </Marker>
                ) : null
              )}
            {filters.rescueTeams && mapData.rescueTeams.map((team) =>
                team.lat && team.lng ? (
                  <Marker key={team.id} position={[team.lat, team.lng]} icon={teamIcon}>
                    <Popup>
                      <b>{team.name}</b>
                      <br />Leader: {team.leader}
                      <br />Status: {team.status}
                      <br />Members: {Array.isArray(team.members) ? team.members.length : "N/A"}
                    </Popup>
                  </Marker>
                ) : null
              )}
            {filters.shelters && mapData.shelters.map((shelter) =>
                shelter.lat && shelter.lng ? (
                  <Marker key={shelter.id} position={[shelter.lat, shelter.lng]} icon={shelterIcon}>
                    <Popup>
                      <b>{shelter.name}</b>
                      <br />Capacity: {shelter.rescuedCount}/{shelter.totalCapacity ?? "?"}
                    </Popup>
                  </Marker>
                ) : null
              )}
            {droppedTeams.map((team, idx) => (
              <Marker
                key={`dropped-${idx}`}
                position={[team.lat, team.lng]}
                icon={teamIcon}
                draggable={team.movable}
                eventHandlers={{
                  dragend: (e) => {
                    const { lat, lng } = e.target.getLatLng();
                    updateTeamPosition(idx, { lat, lng });
                  },
                }}
              >
                <Popup ref={(ref) => (popupRefs.current[idx] = ref)}>
                  <b>{team.name}</b>
                  <br />Leader: {team.leader}
                  <br />Members: {Array.isArray(team.members) ? team.members.length : "N/A"}
                  <div className="mt-3 flex gap-2">
                    <button
                      className={`px-2 py-1 rounded ${team.placed && !team.movable ? "bg-gray-500 cursor-not-allowed" : "bg-green-600 text-white"}`}
                      disabled={team.placed && !team.movable}
                      onClick={() => placeTeam(idx)}
                    >
                      Place
                    </button>
                    <button
                      className="px-2 py-1 bg-red-600 text-white rounded"
                      onClick={() => discardTeam(idx)}
                    >
                      Discard
                    </button>
                    <button
                      className={`px-2 py-1 rounded ${!team.placed ? "bg-gray-500 cursor-not-allowed" : "bg-blue-600 text-white"}`}
                      disabled={!team.placed}
                      onClick={() => enableMove(idx)}
                    >
                      Move
                    </button>
                  </div>
                </Popup>
              </Marker>
            ))}
          </MapContainer>
        </div>

        <div className="w-64 bg-gray-900 rounded-xl p-4 border border-gray-700 h-[70vh] overflow-y-auto">
          <h3 className="text-lg font-semibold text-white mb-3 flex items-center gap-2">
            <SlidersHorizontal size={18} /> Map Filters
          </h3>
          <div className="space-y-3">
            {["messages", "rescueTeams", "shelters", "density"].map((f) => (
            // {["SOS", "Rescue Teams", "Shelters", "Ward Density"].map((f) => (
              <div key={f} className="flex items-center">
                <input
                  type="checkbox"
                  id={f} name={f}
                  checked={filters[f]}
                  onChange={handleFilterChange}
                  className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-600 rounded bg-gray-800"
                />
                <label htmlFor={f} className="ml-3 text-sm font-medium text-gray-300 capitalize">
                  {f === "density" ? "Ward Density" : f}
                </label>
              </div>
            ))}
          </div>
          <div className="mt-4">
            <button
              className={`w-full px-3 py-2 rounded ${isDrawingActive ? "bg-yellow-500 text-black" : "bg-indigo-600 text-white"}`}
              onClick={() => setIsDrawingActive((s) => !s)}
            >
              {isDrawingActive ? "Cancel Alert Draw" : "Send Alert"}
            </button>
            <p className="text-xs text-gray-400 mt-2">
              Click the button, then click+drag on the map to draw a rectangle.
            </p>
          </div>
          <div className="mt-6 border-t border-gray-700 pt-4">
            <h3 className="text-lg font-semibold text-white mb-3">Available Teams</h3>
            <div className="space-y-2 text-sm">
              {(() => {
                const availableTeams = mapData.rescueTeams.filter(team => !team.lat && !team.lng);
                if (availableTeams.length === 0) {
                  return <p className="text-gray-500">No teams currently available.</p>;
                }
                return availableTeams.map(team => (
                  <div key={team.id} className="p-2 bg-gray-800 rounded cursor-move" draggable
                    onDragStart={(e) => e.dataTransfer.setData("team", JSON.stringify(team))}>
                    <p className="font-bold text-white">{team.name}</p>
                    <p className="text-gray-400">Leader: {team.leader}</p>
                    <p className="text-gray-400">Members: {Array.isArray(team.members) ? team.members.length : "N/A"}</p>
                  </div>
                ));
              })()}
            </div>
          </div>
        </div>
      </div>

      {showAlertModal && (
        <div className="fixed inset-0 z-999 flex items-center justify-center">
          <div className="absolute inset-0 bg-black/60" onClick={handleDiscardAlert}></div>
          <div className="relative bg-white rounded-lg w-[min(90%,420px)] p-4 z-10">
            <h3 className="text-lg font-semibold mb-2">Send Alert</h3>
            <p className="text-sm text-gray-600 mb-3">Users found inside selected area: <b>{alertUsers.length}</b></p>
            <textarea
              value={alertMessage}
              onChange={(e) => setAlertMessage(e.target.value)}
              placeholder="Type your alert message here..."
              className="w-full p-2 border border-gray-300 rounded h-28 mb-3 resize-none"
            />
            <div className="flex justify-end gap-2">
              <button className="px-3 py-1 rounded bg-gray-300" onClick={handleDiscardAlert}>
                Discard
              </button>
              <button
                className={`px-3 py-1 rounded ${alertMessage.trim() ? "bg-blue-600 text-white" : "bg-blue-300 cursor-not-allowed"}`}
                onClick={handleSendAlert}
                disabled={!alertMessage.trim()}
              >
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