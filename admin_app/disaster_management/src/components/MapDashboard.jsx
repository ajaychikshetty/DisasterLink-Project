import React, { useState, useEffect, useMemo } from "react";
import {
  MapContainer,
  TileLayer,
  Marker,
  Popup,
  GeoJSON,
  useMap,
} from "react-leaflet";
import L from "leaflet";
import "leaflet.heat";
import { SlidersHorizontal } from "lucide-react";
import booleanPointInPolygon from "@turf/boolean-point-in-polygon";
import { point as turfPoint } from "@turf/helpers";

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

// --- Dummy India-wide Users ---
const generateDummyUsers = () => {
  const users = [];
  const indiaBounds = { latMin: 8, latMax: 37, lngMin: 68, lngMax: 97 };
  for (let i = 0; i < 200; i++) {
    users.push({
      id: i + 1,
      name: `User ${i + 1}`,
      status: Math.random() > 0.5 ? "Safe" : "Need Help",
      lat:
        Math.random() * (indiaBounds.latMax - indiaBounds.latMin) +
        indiaBounds.latMin,
      lng:
        Math.random() * (indiaBounds.lngMax - indiaBounds.lngMin) +
        indiaBounds.lngMin,
    });
  }
  return users;
};

const dummyRescueTeams = [
  { id: 1, name: "Rescue Team A", leader: "Rohit", status: "Active", lat: 28.6139, lng: 77.209 },
  { id: 2, name: "Rescue Team B", leader: "Priya", status: "Engaged", lat: 19.076, lng: 72.878 },
  { id: 3, name: "Rescue Team C", leader: "Amit", status: "Free", lat: 12.9716, lng: 77.5946 },
];

const dummyShelters = [
  { id: 1, name: "Shelter 1", totalCapacity: 100, rescuedCount: 45, lat: 28.7041, lng: 77.1025 },
  { id: 2, name: "Shelter 2", totalCapacity: 150, rescuedCount: 90, lat: 19.2288, lng: 72.854 },
  { id: 3, name: "Shelter 3", totalCapacity: 200, rescuedCount: 120, lat: 13.0827, lng: 80.2707 },
];

// --- Dynamic Boundary Layer ---
const DynamicBoundaryLayer = ({ users }) => {
  const [geoData, setGeoData] = useState(null);
  const map = useMap();

  const fetchBoundaries = async () => {
    const zoom = map.getZoom();
    const bounds = map.getBounds();

    const boundsQuery = JSON.stringify({
      _southWest: bounds.getSouthWest(),
      _northEast: bounds.getNorthEast(),
    });

    try {
      const response = await fetch(
        `http://localhost:8000/api/map/boundaries?zoom=${zoom}&bounds=${encodeURIComponent(
          boundsQuery
        )}`
      );
      if (!response.ok) throw new Error("Failed to fetch GeoJSON");
      const data = await response.json();
      setGeoData(data);
    } catch (err) {
      console.error(err);
    }
  };

  useEffect(() => {
    fetchBoundaries();
    map.on("moveend zoomend", fetchBoundaries);
    return () => map.off("moveend zoomend", fetchBoundaries);
  }, [map]);

  const featureDensity = useMemo(() => {
    if (!geoData || !users) return {};
    const density = {};
    geoData.features.forEach((feature, i) => (density[i] = 0));
    users.forEach((u) => {
      const pt = turfPoint([u.lng, u.lat]);
      geoData.features.forEach((f, i) => {
        if (booleanPointInPolygon(pt, f)) density[i] += 1;
      });
    });
    return density;
  }, [geoData, users]);

  const getColor = (d) =>
    d > 10 ? "#800026" :
    d > 7  ? "#BD0026" :
    d > 4  ? "#E31A1C" :
    d > 2  ? "#FC4E2A" :
    d > 0  ? "#FD8D3C" :
             "#FFEDA0";

  return geoData ? (
    <GeoJSON
      key={JSON.stringify(geoData)}
      data={geoData}
      style={(feature) => {
        const idx = geoData.features.indexOf(feature);
        return {
          fillColor: getColor(featureDensity[idx] || 0),
          weight: 1,
          opacity: 1,
          color: "black",  // black border like old map
          fillOpacity: 0.7, // more visible on dark map
        };
      }}
      onEachFeature={(feature, layer) => {
        const idx = geoData.features.indexOf(feature);
        const name =
          feature.properties.NAME_0 ||
          feature.properties.NAME_1 ||
          feature.properties.NAME_2 ||
          feature.properties.NAME_3 ||
          "Unknown";
        layer.bindPopup(
          `<b>${name}</b><br/>People in Need: ${featureDensity[idx] || 0}`
        );
      }}
    />
  ) : null;
};

// --- Main Map Dashboard ---
const MapDashboard = () => {
  const [users] = useState(generateDummyUsers);
  const [filters, setFilters] = useState({
    users: true,
    rescueTeams: true,
    shelters: true,
    density: true,
  });

  const initialPosition = [20.5937, 78.9629]; // Center of India
  const initialZoom = 5;

  const handleFilterChange = (e) => {
    const { name, checked } = e.target;
    setFilters((prev) => ({ ...prev, [name]: checked }));
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">India Disaster Map</h1>
          <p className="text-gray-400 mt-1">
            Dynamic boundaries, user density, teams, and shelters
          </p>
        </div>
      </div>

      <div className="flex gap-6">
        <div className="flex-1 bg-gray-800 rounded-xl overflow-hidden" style={{ height: "70vh" }}>
          <MapContainer center={initialPosition} zoom={initialZoom} style={{ height: "100%", width: "100%" }}>
            <TileLayer
              attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
              url="https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
            />

            {filters.density && <DynamicBoundaryLayer users={users} />}

            {filters.users &&
              users.map((user) => (
                <Marker key={user.id} position={[user.lat, user.lng]} icon={userIcon}>
                  <Popup><b>{user.name}</b><br />Status: {user.status}</Popup>
                </Marker>
              ))}

            {filters.rescueTeams &&
              dummyRescueTeams.map((team) => (
                <Marker key={team.id} position={[team.lat, team.lng]} icon={teamIcon}>
                  <Popup><b>{team.name}</b><br />Leader: {team.leader}<br />Status: {team.status}</Popup>
                </Marker>
              ))}

            {filters.shelters &&
              dummyShelters.map((shelter) => (
                <Marker key={shelter.id} position={[shelter.lat, shelter.lng]} icon={shelterIcon}>
                  <Popup><b>{shelter.name}</b><br />Capacity: {shelter.rescuedCount}/{shelter.totalCapacity}</Popup>
                </Marker>
              ))}
          </MapContainer>
        </div>

        <div className="w-64 bg-gray-900 rounded-xl p-4 border border-gray-700 h-[70vh]">
          <h3 className="text-lg font-semibold text-white mb-3 flex items-center gap-2">
            <SlidersHorizontal size={18} /> Map Filters
          </h3>
          <div className="space-y-3">
            {["users", "rescueTeams", "shelters", "density"].map((f) => (
              <div key={f} className="flex items-center">
                <input
                  type="checkbox"
                  id={f}
                  name={f}
                  checked={filters[f]}
                  onChange={handleFilterChange}
                  className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-600 rounded bg-gray-800"
                />
                <label htmlFor={f} className="ml-3 text-sm font-medium text-gray-300 capitalize">
                  {f === "density" ? "Boundary Density" : f.replace('Teams',' Teams')}
                </label>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
};

export default MapDashboard;
