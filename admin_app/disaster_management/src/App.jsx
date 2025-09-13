import 'leaflet/dist/leaflet.css';

import 'leaflet/dist/leaflet.css';
import React, { useState, useEffect, useCallback, useMemo } from 'react';
import { 
  Menu, X, Home, Map, Users, Shield, UserCheck, Building,
  Bell, User, Search, Plus, Edit, Trash2, MapPin, Phone,
  Calendar, Activity, ChevronRight, AlertCircle, CheckCircle,
  Clock, Settings, LogOut
} from 'lucide-react';

import UserManagement from './components/UserManagement';
import RescuerManagement from './components/RescuerManagement';
import DashboardOverview from './components/DashboardOverview';
import ShelterManagement from './components/ShelterManagement';
import RescueOpsDashboard from './components/RescueOpsDashboard';
import MapDashboard from './components/MapDashboard';

import * as shelterService from './services/shelterService';
import * as rescuerService from './services/rescuerService';
import * as rescueOpsService from './services/rescueOpsService';
import * as userService from './services/userService';

import * as mapService from './services/mapService';
import SlideInForm from './components/SlideInForm';


// Main App Component with Navigation
const App = () => {
  const [activeTab, setActiveTab] = useState(() => {
    return localStorage.getItem('activeTab') || 'dashboard';
  });
  const [sidebarOpen, setSidebarOpen] = useState(false);

  useEffect(() => {
    localStorage.setItem('activeTab', activeTab);
  }, [activeTab]);

  const navigation = [
    { id: 'dashboard', name: 'Dashboard', icon: Home },
    { id: 'map', name: 'Live Map', icon: Map },
    { id: 'users', name: 'Users', icon: Users },
    { id: 'rescuers', name: 'Rescuers', icon: Shield },
    { id: 'teams', name: 'Rescue Teams', icon: UserCheck },
    { id: 'shelters', name: 'Shelters', icon: Building },
  ];

  const renderContent = () => {
    switch (activeTab) {
      case 'dashboard':
        return <DashboardOverview />;
      case 'map':
        return <MapDashboard />;
      case 'users':
        return <UserManagement />;
      case 'rescuers':
        return <RescuerManagement />;
      case 'teams':
        return <RescueOpsDashboard />;
      case 'shelters':
        return <ShelterManagement />;
      default:
        return <DashboardOverview />;
    }
  };

  return (
    <div className="min-h-screen bg-gray-900 flex">
      {/* Mobile sidebar overlay */}
      {sidebarOpen && (
        <div className="fixed inset-0 bg-black bg-opacity-50 lg:hidden z-40" onClick={() => setSidebarOpen(false)} />
      )}

      {/* Sidebar */}
      <div className={`fixed inset-y-0 left-0 z-50 w-64 bg-gray-800 transform ${sidebarOpen ? 'translate-x-0' : '-translate-x-full'} transition-transform duration-300 ease-in-out lg:translate-x-0 lg:static lg:inset-0`}>
        <div className="flex items-center justify-between h-16 px-6 border-b border-gray-700">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 bg-indigo-600 rounded-lg flex items-center justify-center">
              <Shield size={20} className="text-white" />
            </div>
            <span className="text-xl font-bold text-white">RescueOps</span>
          </div>
          <button
            onClick={() => setSidebarOpen(false)}
            className="lg:hidden text-gray-400 hover:text-white"
          >
            <X size={24} />
          </button>
        </div>

        <nav className="mt-6">
          <div className="px-3">
            {navigation.map((item) => {
              const Icon = item.icon;
              return (
                <button
                  key={item.id}
                  onClick={() => {
                    setActiveTab(item.id);
                    setSidebarOpen(false);
                  }}
                  className={`w-full flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-colors mb-1 ${
                    activeTab === item.id
                      ? 'bg-indigo-600 text-white'
                      : 'text-gray-300 hover:bg-gray-700 hover:text-white'
                  }`}
                >
                  <Icon size={20} />
                  {item.name}
                </button>
              );
            })}
          </div>
        </nav>

        {/* User profile section */}
        <div className="absolute bottom-0 left-0 right-0 p-4 border-t border-gray-700">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 bg-gray-600 rounded-full flex items-center justify-center">
              <User size={16} className="text-white" />
            </div>
            <div className="flex-1">
              <p className="text-sm font-medium text-white">Admin User</p>
              <p className="text-xs text-gray-400">Emergency Coordinator</p>
            </div>
            <button className="text-gray-400 hover:text-white">
              <Settings size={16} />
            </button>
          </div>
        </div>
      </div>

      {/* Main content */}
      <div className="flex-1 lg:ml-0">
        {/* Top header */}
        <header className="bg-gray-800 border-b border-gray-700 h-16 flex items-center justify-between px-6">
          <button
            onClick={() => setSidebarOpen(true)}
            className="lg:hidden text-gray-400 hover:text-white"
          >
            <Menu size={24} />
          </button>

          <div className="flex-1 max-w-md mx-4">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400" size={16} />
              <input
                type="text"
                placeholder="Search..."
                className="w-full bg-gray-700 border border-gray-600 rounded-lg pl-10 pr-4 py-2 text-white placeholder-gray-400 focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
              />
            </div>
          </div>

          <div className="flex items-center gap-4">
            <button className="text-gray-400 hover:text-white relative">
              <Bell size={20} />
              <span className="absolute -top-1 -right-1 w-3 h-3 bg-red-500 rounded-full"></span>
            </button>
            <div className="w-8 h-8 bg-indigo-600 rounded-full flex items-center justify-center">
              <User size={16} className="text-white" />
            </div>
          </div>
        </header>

        {/* Page content */}
        <main className="p-6">
          {renderContent()}
        </main>
      </div>
    </div>
  );
};

export default App;
























// map 
// import React, { useState, useEffect, useMemo } from "react";
// import {
//   MapContainer,
//   TileLayer,
//   Marker,
//   Popup,
//   GeoJSON,
// } from "react-leaflet";
// import L from "leaflet";
// import "leaflet.heat";
// import { SlidersHorizontal } from "lucide-react";
// import booleanPointInPolygon from "@turf/boolean-point-in-polygon";
// import { point as turfPoint } from "@turf/helpers";

// // --- Fix Leaflet Icon Path Issue ---
// import markerIcon2x from "leaflet/dist/images/marker-icon-2x.png";
// import markerIcon from "leaflet/dist/images/marker-icon.png";
// import markerShadow from "leaflet/dist/images/marker-shadow.png";
// delete L.Icon.Default.prototype._getIconUrl;
// L.Icon.Default.mergeOptions({
//   iconRetinaUrl: markerIcon2x,
//   iconUrl: markerIcon,
//   shadowUrl: markerShadow,
// });

// // --- Custom Icons ---
// const userIcon = new L.Icon({
//   iconUrl:
//     "https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-blue.png",
//   shadowUrl: markerShadow,
//   iconSize: [25, 41],
//   iconAnchor: [12, 41],
//   popupAnchor: [1, -34],
//   shadowSize: [41, 41],
// });
// const teamIcon = new L.Icon({
//   iconUrl:
//     "https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-red.png",
//   shadowUrl: markerShadow,
//   iconSize: [25, 41],
//   iconAnchor: [12, 41],
//   popupAnchor: [1, -34],
//   shadowSize: [41, 41],
// });
// const shelterIcon = new L.Icon({
//   iconUrl:
//     "https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-green.png",
//   shadowUrl: markerShadow,
//   iconSize: [25, 41],
//   iconAnchor: [12, 41],
//   popupAnchor: [1, -34],
//   shadowSize: [41, 41],
// });

// // --- Dummy Data for Mumbai ---
// const generateDummyUsers = () => {
//   const users = [];
//   const mumbaiBounds = {
//     latMin: 18.88,
//     latMax: 19.3,
//     lngMin: 72.77,
//     lngMax: 72.99,
//   };

//   for (let i = 0; i < 50; i++) {
//     users.push({
//       id: i + 1,
//       name: `User ${i + 1}`,
//       status: Math.random() > 0.5 ? "Safe" : "Need Help",
//       lat:
//         Math.random() * (mumbaiBounds.latMax - mumbaiBounds.latMin) +
//         mumbaiBounds.latMin,
//       lng:
//         Math.random() * (mumbaiBounds.lngMax - mumbaiBounds.lngMin) +
//         mumbaiBounds.lngMin,
//     });
//   }
//   return users;
// };

// const dummyRescueTeams = [
//   { id: 1, name: "Rescue Team A", leader: "Rohit", status: "Active", lat: 19.076, lng: 72.8777 },
//   { id: 2, name: "Rescue Team B", leader: "Priya", status: "Engaged", lat: 19.1, lng: 72.85 },
//   { id: 3, name: "Rescue Team C", leader: "Amit", status: "Free", lat: 19.2, lng: 72.9 },
// ];

// const dummyShelters = [
//   { id: 1, name: "Shelter 1", totalCapacity: 100, rescuedCount: 45, lat: 19.08, lng: 72.84 },
//   { id: 2, name: "Shelter 2", totalCapacity: 150, rescuedCount: 90, lat: 19.12, lng: 72.86 },
//   { id: 3, name: "Shelter 3", totalCapacity: 200, rescuedCount: 120, lat: 19.18, lng: 72.88 },
//   { id: 4, name: "Shelter 4", totalCapacity: 80, rescuedCount: 50, lat: 19.22, lng: 72.89 },
//   { id: 5, name: "Shelter 5", totalCapacity: 60, rescuedCount: 20, lat: 19.15, lng: 72.83 },
// ];

// // --- Choropleth Density Component ---
// const ChoroplethLayer = ({ users }) => {
//   const [geoData, setGeoData] = useState(null);

//   useEffect(() => {
//     fetch("http://localhost:8000/api/map/mumbai-map")
//       .then((res) => res.json())
//       .then((data) => setGeoData(data));
//   }, []);

//   const wardDensity = useMemo(() => {
//     if (!geoData) return {};
//     const density = {};
//     geoData.features.forEach((f, i) => {
//       density[i] = 0;
//     });

//     users.forEach((u) => {
//       const pt = turfPoint([u.lng, u.lat]);
//       geoData.features.forEach((f, i) => {
//         if (
//           f.geometry.type === "Polygon" ||
//           f.geometry.type === "MultiPolygon"
//         ) {
//           if (booleanPointInPolygon(pt, f)) {
//             density[i] += 1;
//           }
//         }
//       });
//     });
//     return density;
//   }, [geoData, users]);

//   const getColor = (d) =>
//     d > 10 ? "#800026" :
//     d > 7  ? "#BD0026" :
//     d > 4  ? "#E31A1C" :
//     d > 2  ? "#FC4E2A" :
//     d > 0  ? "#FD8D3C" :
//              "#FFEDA0";

//   return geoData ? (
//     <GeoJSON
//       data={geoData}
//       style={(feature) => {
//         const idx = geoData.features.indexOf(feature);
//         return {
//           fillColor: getColor(wardDensity[idx] || 0),
//           weight: 1,
//           opacity: 1,
//           color: "black",
//           fillOpacity: 0.7,
//         };
//       }}
//       onEachFeature={(feature, layer) => {
//         const idx = geoData.features.indexOf(feature);
//         layer.bindPopup(
//           `Ward: ${feature.properties.name || "Unknown"}<br/>People: ${
//             wardDensity[idx] || 0
//           }`
//         );
//       }}
//     />
//   ) : null;
// };

// // --- Main Dashboard ---
// const MapDashboard = () => {
//   const [users] = useState(generateDummyUsers);
//   const [filters, setFilters] = useState({
//     users: true,
//     rescueTeams: true,
//     shelters: true,
//     density: true,
//   });

//   const initialPosition = [19.076, 72.8777];

//   const handleFilterChange = (event) => {
//     const { name, checked } = event.target;
//     setFilters((prev) => ({ ...prev, [name]: checked }));
//   };

//   return (
//     <div className="space-y-6">
//       {/* Header */}
//       <div className="flex items-center justify-between">
//         <div>
//           <h1 className="text-2xl font-bold text-white">Mumbai Disaster Map</h1>
//           <p className="text-gray-400 mt-1">
//             Ward density, users, rescue teams, and shelters
//           </p>
//         </div>
//       </div>

//       <div className="flex gap-6">
//         {/* Map */}
//         <div className="flex-1 bg-gray-800 rounded-xl overflow-hidden" style={{ height: "70vh" }}>
//           <MapContainer center={initialPosition} zoom={12} style={{ height: "100%", width: "100%" }}>
//             <TileLayer
//               attribution="&copy; OpenStreetMap"
//               url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
//             />

//             {/* Choropleth Density */}
//             {filters.density && <ChoroplethLayer users={users} />}

//             {/* Users */}
//             {filters.users &&
//               users.map((user) => (
//                 <Marker key={user.id} position={[user.lat, user.lng]} icon={userIcon}>
//                   <Popup>
//                     <b>{user.name}</b>
//                     <br />Status: {user.status}
//                   </Popup>
//                 </Marker>
//               ))}

//             {/* Rescue Teams */}
//             {filters.rescueTeams &&
//               dummyRescueTeams.map((team) => (
//                 <Marker key={team.id} position={[team.lat, team.lng]} icon={teamIcon}>
//                   <Popup>
//                     <b>{team.name}</b>
//                     <br />Leader: {team.leader}
//                     <br />Status: {team.status}
//                   </Popup>
//                 </Marker>
//               ))}

//             {/* Shelters */}
//             {filters.shelters &&
//               dummyShelters.map((shelter) => (
//                 <Marker key={shelter.id} position={[shelter.lat, shelter.lng]} icon={shelterIcon}>
//                   <Popup>
//                     <b>{shelter.name}</b>
//                     <br />Capacity: {shelter.rescuedCount}/{shelter.totalCapacity}
//                   </Popup>
//                 </Marker>
//               ))}
//           </MapContainer>
//         </div>

//         {/* Filters */}
//         <div className="w-64 bg-gray-900 rounded-xl p-4 border border-gray-700 h-[70vh]">
//           <h3 className="text-lg font-semibold text-white mb-3 flex items-center gap-2">
//             <SlidersHorizontal size={18} /> Map Filters
//           </h3>
//           <div className="space-y-3">
//             {["users", "rescueTeams", "shelters", "density"].map((f) => (
//               <div key={f} className="flex items-center">
//                 <input
//                   type="checkbox"
//                   id={f}
//                   name={f}
//                   checked={filters[f]}
//                   onChange={handleFilterChange}
//                   className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-600 rounded bg-gray-800"
//                 />
//                 <label htmlFor={f} className="ml-3 text-sm font-medium text-gray-300 capitalize">
//                   {f === "density" ? "Ward Density" : f}
//                 </label>
//               </div>
//             ))}
//           </div>
//         </div>
//       </div>
//     </div>
//   );
// };

// export default MapDashboard;
