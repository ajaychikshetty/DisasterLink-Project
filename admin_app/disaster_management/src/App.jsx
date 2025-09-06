import 'leaflet/dist/leaflet.css';
// import React from 'react';
// import UserManagement from './components/UserManagement';
// import ShelterManagement from './components/ShelterManagement';
// import RescuerManagement from './components/RescuerManagement';
// import RescueOpsDashboard from './components/RescueOpsDashboard';
// import MapDashboard from './components/MapDashboard';

// function App() {
//   return (
//     <div className="App">
//       <UserManagement />
//       <ShelterManagement />
//       <RescuerManagement />
//       <RescueOpsDashboard />
//       <MapDashboard />
//     </div>
//   );
// }

// export default App;














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



// // Rescue Operations Dashboard Component
// const RescueOpsDashboard = () => {
//   const [teams, setTeams] = useState([]);
//   const [allRescuers, setAllRescuers] = useState([]);
//   const [shelters, setShelters] = useState([]);
//   const [isLoading, setIsLoading] = useState(true);
//   const [error, setError] = useState(null);
//   const [isTeamFormVisible, setIsTeamFormVisible] = useState(false);
//   const [editingTeam, setEditingTeam] = useState(null);
//   const [message, setMessage] = useState('');

//   // Team Form Data
//   const [teamFormData, setTeamFormData] = useState({ teamId: '', name: '', leader: '' });
//   const [selectedMembers, setSelectedMembers] = useState(new Set());

//   // Rescue Log Form Data
//   const [rescueLogData, setRescueLogData] = useState({ shelterId: '', total: 0, kids: 0, women: 0, men: 0 });

//   // Dispatch Form Data
//   const [dispatchMode, setDispatchMode] = useState('auto');
//   const [dispatchData, setDispatchData] = useState({ incidentId: '', latitude: '', longitude: '', teamId: '' });

//   const fetchAllData = useCallback(async () => {
//     try {
//       setIsLoading(true);
//       const [teamsData, rescuersData, sheltersData] = await Promise.all([
//         rescueOpsService.getRescueTeams(),
//         rescuerService.getRescuers(),
//         shelterService.getShelters()
//       ]);
//       setTeams(teamsData);
//       setAllRescuers(rescuersData);
//       setShelters(sheltersData);
//     } catch (err) {
//       setError(err.message);
//     } finally {
//       setIsLoading(false);
//     }
//   }, []);

//   useEffect(() => {
//     fetchAllData();
//   }, [fetchAllData]);

//   useEffect(() => {
//     if (editingTeam) {
//       setTeamFormData({ teamId: editingTeam.teamId, name: editingTeam.name, leader: editingTeam.leader || '' });
//       setSelectedMembers(new Set(editingTeam.members || []));
//     } else {
//       setTeamFormData({ teamId: '', name: '', leader: '' });
//       setSelectedMembers(new Set());
//     }
//   }, [editingTeam]);

//   const { currentMembersDetails, availableForHire, selectableRescuers, leaderOptions } = useMemo(() => {
//     const currentMembersDetails = editingTeam ? allRescuers.filter(r => editingTeam.members.includes(r.username)) : [];
//     const availableForHire = allRescuers.filter(r => r.status === 'Free' && r.teamId === null);
//     const selectableRescuers = [...currentMembersDetails, ...availableForHire]
//       .filter((v, i, a) => a.findIndex(t => t.username === v.username) === i);
//     const leaderOptions = allRescuers.filter(r => selectedMembers.has(r.username));
//     return { currentMembersDetails, availableForHire, selectableRescuers, leaderOptions };
//   }, [allRescuers, editingTeam, selectedMembers]);

//   const handleMemberToggle = (username) => {
//     const newSelected = new Set(selectedMembers);
//     if (newSelected.has(username)) {
//       newSelected.delete(username);
//       if (teamFormData.leader === username) {
//         setTeamFormData(prev => ({ ...prev, leader: '' }));
//       }
//     } else {
//       newSelected.add(username);
//     }
//     setSelectedMembers(newSelected);
//   };

//   const handleSaveTeam = async (e) => {
//     e.preventDefault();
//     try {
//       const finalData = { ...teamFormData, members: Array.from(selectedMembers) };
//       if (editingTeam) {
//         await rescueOpsService.updateRescueTeam(editingTeam.teamId, finalData);
//       } else {
//         await rescueOpsService.createRescueTeam(finalData);
//       }
//       setIsTeamFormVisible(false);
//       setEditingTeam(null);
//       fetchAllData();
//     } catch (err) {
//       console.error("Save failed:", err);
//     }
//   };

//   const handleDeleteTeam = async (teamId) => {
//     if (window.confirm('Are you sure you want to delete this team?')) {
//       await rescueOpsService.deleteRescueTeam(teamId);
//       fetchAllData();
//     }
//   };

//   const handleLogRescue = async (e) => {
//     e.preventDefault();
//     setMessage('');
//     const logData = {
//       shelterId: rescueLogData.shelterId,
//       rescuedCount: {
//         total: parseInt(rescueLogData.total),
//         kids: parseInt(rescueLogData.kids),
//         women: parseInt(rescueLogData.women),
//         men: parseInt(rescueLogData.men)
//       }
//     };
//     try {
//       const result = await rescueOpsService.logRescueToShelter(logData);
//       setMessage(`Success: ${result.message}`);
//       setRescueLogData({ shelterId: '', total: 0, kids: 0, women: 0, men: 0 });
//     } catch (err) {
//       setMessage(`Error: ${err.message}`);
//     }
//   };

//   const handleDispatch = async (e) => {
//     e.preventDefault();
//     setMessage('');
//     try {
//       let result;
//       if (dispatchMode === 'auto') {
//         result = await rescueOpsService.autoAssignTeamToIncident({
//           incidentId: dispatchData.incidentId,
//           latitude: parseFloat(dispatchData.latitude),
//           longitude: parseFloat(dispatchData.longitude)
//         });
//       } else {
//         result = await rescueOpsService.manualAssignTeam(dispatchData.teamId, dispatchData.incidentId);
//       }
//       setMessage(`Success: ${result.message}`);
//       fetchAllData();
//     } catch (err) {
//       setMessage(`Error: ${err.message}`);
//     }
//   };

//   const freeTeams = teams.filter(t => t.status === 'Free');

//   return (
//     <div className="space-y-6">
//       <div>
//         <h1 className="text-2xl font-bold text-white">Rescue Operations Center</h1>
//         <p className="text-gray-400 mt-1">Coordinate rescue teams and operations</p>
//       </div>

//       {message && (
//         <div className={`p-4 rounded-lg ${message.startsWith('Error') ? 'bg-red-900/50 border border-red-500 text-red-400' : 'bg-green-900/50 border border-green-500 text-green-400'}`}>
//           {message}
//         </div>
//       )}

//       <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
//         {/* Log Rescued People */}
//         <div className="bg-gray-800 rounded-xl p-6">
//           <h2 className="text-xl font-semibold text-white mb-4">Log Rescued People</h2>
//           <form onSubmit={handleLogRescue} className="space-y-4">
//             <div>
//               <label className="block text-sm font-medium text-gray-300 mb-2">Select Shelter</label>
//               <select
//                 value={rescueLogData.shelterId}
//                 onChange={(e) => setRescueLogData(prev => ({ ...prev, shelterId: e.target.value }))}
//                 className="w-full bg-gray-700 border border-gray-600 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-green-500 focus:border-transparent"
//                 required
//               >
//                 <option value="">Select a Shelter</option>
//                 {shelters.map(s => (
//                   <option key={s.id} value={s.id}>{s.name}</option>
//                 ))}
//               </select>
//             </div>
            
//             <div>
//               <label className="block text-sm font-medium text-gray-300 mb-2">Total Rescued</label>
//               <input
//                 type="number"
//                 value={rescueLogData.total}
//                 onChange={(e) => setRescueLogData(prev => ({ ...prev, total: e.target.value }))}
//                 className="w-full bg-gray-700 border border-gray-600 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-green-500 focus:border-transparent"
//                 required
//               />
//             </div>

//             <div className="grid grid-cols-3 gap-4">
//               <div>
//                 <label className="block text-sm font-medium text-gray-300 mb-2">Kids</label>
//                 <input
//                   type="number"
//                   value={rescueLogData.kids}
//                   onChange={(e) => setRescueLogData(prev => ({ ...prev, kids: e.target.value }))}
//                   className="w-full bg-gray-700 border border-gray-600 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-green-500 focus:border-transparent"
//                 />
//               </div>
//               <div>
//                 <label className="block text-sm font-medium text-gray-300 mb-2">Women</label>
//                 <input
//                   type="number"
//                   value={rescueLogData.women}
//                   onChange={(e) => setRescueLogData(prev => ({ ...prev, women: e.target.value }))}
//                   className="w-full bg-gray-700 border border-gray-600 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-green-500 focus:border-transparent"
//                 />
//               </div>
//               <div>
//                 <label className="block text-sm font-medium text-gray-300 mb-2">Men</label>
//                 <input
//                   type="number"
//                   value={rescueLogData.men}
//                   onChange={(e) => setRescueLogData(prev => ({ ...prev, men: e.target.value }))}
//                   className="w-full bg-gray-700 border border-gray-600 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-green-500 focus:border-transparent"
//                 />
//               </div>
//             </div>

//             <button
//               type="submit"
//               className="w-full bg-green-600 hover:bg-green-700 text-white font-semibold py-2 px-4 rounded-lg transition-colors"
//             >
//               Log Rescue
//             </button>
//           </form>
//         </div>

//         {/* Dispatch Team */}
//         <div className="bg-gray-800 rounded-xl p-6">
//           <h2 className="text-xl font-semibold text-white mb-4">Dispatch Team to Incident</h2>
          
//           <div className="flex mb-4 bg-gray-700 rounded-lg p-1">
//             <button
//               onClick={() => setDispatchMode('auto')}
//               className={`flex-1 py-2 px-4 rounded-md text-sm font-medium transition-colors ${
//                 dispatchMode === 'auto' ? 'bg-orange-600 text-white' : 'text-gray-300 hover:text-white'
//               }`}
//             >
//               Auto-Assign
//             </button>
//             <button
//               onClick={() => setDispatchMode('manual')}
//               className={`flex-1 py-2 px-4 rounded-md text-sm font-medium transition-colors ${
//                 dispatchMode === 'manual' ? 'bg-orange-600 text-white' : 'text-gray-300 hover:text-white'
//               }`}
//             >
//               Manual Assign
//             </button>
//           </div>

//           <form onSubmit={handleDispatch} className="space-y-4">
//             <div>
//               <label className="block text-sm font-medium text-gray-300 mb-2">Incident ID</label>
//               <input
//                 type="text"
//                 value={dispatchData.incidentId}
//                 onChange={(e) => setDispatchData(prev => ({ ...prev, incidentId: e.target.value }))}
//                 className="w-full bg-gray-700 border border-gray-600 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-orange-500 focus:border-transparent"
//                 required
//               />
//             </div>

//             {dispatchMode === 'auto' && (
//               <div className="grid grid-cols-2 gap-4">
//                 <div>
//                   <label className="block text-sm font-medium text-gray-300 mb-2">Latitude</label>
//                   <input
//                     type="number"
//                     step="any"
//                     value={dispatchData.latitude}
//                     onChange={(e) => setDispatchData(prev => ({ ...prev, latitude: e.target.value }))}
//                     className="w-full bg-gray-700 border border-gray-600 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-orange-500 focus:border-transparent"
//                     required
//                   />
//                 </div>
//                 <div>
//                   <label className="block text-sm font-medium text-gray-300 mb-2">Longitude</label>
//                   <input
//                     type="number"
//                     step="any"
//                     value={dispatchData.longitude}
//                     onChange={(e) => setDispatchData(prev => ({ ...prev, longitude: e.target.value }))}
//                     className="w-full bg-gray-700 border border-gray-600 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-orange-500 focus:border-transparent"
//                     required
//                   />
//                 </div>
//               </div>
//             )}

//             {dispatchMode === 'manual' && (
//               <div>
//                 <label className="block text-sm font-medium text-gray-300 mb-2">Select Team</label>
//                 <select
//                   value={dispatchData.teamId}
//                   onChange={(e) => setDispatchData(prev => ({ ...prev, teamId: e.target.value }))}
//                   className="w-full bg-gray-700 border border-gray-600 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-orange-500 focus:border-transparent"
//                   required
//                 >
//                   <option value="">Select a Free Team</option>
//                   {freeTeams.map(t => (
//                     <option key={t.teamId} value={t.teamId}>{t.name}</option>
//                   ))}
//                 </select>
//               </div>
//             )}

//             <button
//               type="submit"
//               className="w-full bg-orange-600 hover:bg-orange-700 text-white font-semibold py-2 px-4 rounded-lg transition-colors"
//             >
//               Dispatch Team
//             </button>
//           </form>
//         </div>
//       </div>

//       {/* Team Management */}
//       <div className="bg-gray-800 rounded-xl p-6">
//         <div className="flex items-center justify-between mb-6">
//           <h2 className="text-xl font-semibold text-white">Manage Rescue Teams</h2>
//           <button
//             onClick={() => { setEditingTeam(null); setIsTeamFormVisible(true); }}
//             className="flex items-center gap-2 bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2 rounded-lg transition-colors"
//           >
//             <Plus size={16} />
//             Add Team
//           </button>
//         </div>

//         {isLoading && (
//           <div className="text-center py-8">
//             <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-500"></div>
//             <p className="text-gray-400 mt-2">Loading teams...</p>
//           </div>
//         )}

//         {error && (
//           <div className="bg-red-900/50 border border-red-500 rounded-lg p-4">
//             <div className="flex items-center gap-2 text-red-400">
//               <AlertCircle size={20} />
//               <span>{error}</span>
//             </div>
//           </div>
//         )}

//         {!isLoading && !error && (
//           <div className="overflow-x-auto">
//             <table className="w-full">
//               <thead className="bg-gray-700">
//                 <tr>
//                   <th className="px-6 py-4 text-left text-xs font-medium text-gray-300 uppercase tracking-wider">Team</th>
//                   <th className="px-6 py-4 text-left text-xs font-medium text-gray-300 uppercase tracking-wider">Members</th>
//                   <th className="px-6 py-4 text-left text-xs font-medium text-gray-300 uppercase tracking-wider">Status</th>
//                   <th className="px-6 py-4 text-left text-xs font-medium text-gray-300 uppercase tracking-wider">Actions</th>
//                 </tr>
//               </thead>
//               <tbody className="divide-y divide-gray-700">
//                 {teams.map(team => (
//                   <tr key={team.teamId} className="hover:bg-gray-700/50">
//                     <td className="px-6 py-4">
//                       <div className="flex items-center gap-3">
//                         <div className="w-10 h-10 bg-indigo-600 rounded-full flex items-center justify-center">
//                           <UserCheck size={20} className="text-white" />
//                         </div>
//                         <div>
//                           <div className="text-sm font-medium text-white">{team.name}</div>
//                           <div className="text-sm text-gray-400">Leader: {team.leader}</div>
//                         </div>
//                       </div>
//                     </td>
//                     <td className="px-6 py-4">
//                       <div className="text-sm text-white">{team.members.join(', ') || 'None'}</div>
//                     </td>
//                     <td className="px-6 py-4">
//                       <span className={`px-2 py-1 text-xs font-medium rounded-full ${
//                         team.status === 'Free' ? 'bg-green-900 text-green-300' : 
//                         team.status === 'Disabled' ? 'bg-red-900 text-red-300' : 
//                         'bg-yellow-900 text-yellow-300'
//                       }`}>
//                         {team.status}
//                       </span>
//                     </td>
//                     <td className="px-6 py-4">
//                       <div className="flex items-center gap-2">
//                         <button
//                           onClick={() => { setEditingTeam(team); setIsTeamFormVisible(true); }}
//                           className="text-indigo-400 hover:text-indigo-300"
//                         >
//                           <Edit size={16} />
//                         </button>
//                         <button
//                           onClick={() => handleDeleteTeam(team.teamId)}
//                           className="text-red-400 hover:text-red-300"
//                         >
//                           <Trash2 size={16} />
//                         </button>
//                       </div>
//                     </td>
//                   </tr>
//                 ))}
//               </tbody>
//             </table>
//           </div>
//         )}
//       </div>

//       {/* Team Form Modal */}
//       <SlideInForm
//         isOpen={isTeamFormVisible}
//         onClose={() => setIsTeamFormVisible(false)}
//         title={editingTeam ? 'Edit Team' : 'Create New Team'}
//       >
//         <form onSubmit={handleSaveTeam} className="space-y-6">
//           <div className="space-y-4">
//             <div>
//               <label className="block text-sm font-medium text-gray-300 mb-2">Team ID</label>
//               <input
//                 type="text"
//                 value={teamFormData.teamId}
//                 onChange={(e) => setTeamFormData({...teamFormData, teamId: e.target.value})}
//                 disabled={!!editingTeam}
//                 className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-indigo-500 focus:border-transparent disabled:opacity-50"
//                 required
//               />
//             </div>
            
//             <div>
//               <label className="block text-sm font-medium text-gray-300 mb-2">Team Name</label>
//               <input
//                 type="text"
//                 value={teamFormData.name}
//                 onChange={(e) => setTeamFormData({...teamFormData, name: e.target.value})}
//                 className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
//                 required
//               />
//             </div>
            
//             <div>
//               <label className="block text-sm font-medium text-gray-300 mb-2">Team Leader</label>
//               <select
//                 value={teamFormData.leader}
//                 onChange={(e) => setTeamFormData({...teamFormData, leader: e.target.value})}
//                 className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
//                 required
//               >
//                 <option value="">Select Leader (from members)</option>
//                 {leaderOptions.map(r => (
//                   <option key={r.username} value={r.username}>
//                     {r.name} ({r.username})
//                   </option>
//                 ))}
//               </select>
//             </div>
//           </div>

//           <div>
//             <label className="block text-sm font-medium text-gray-300 mb-3">Team Members</label>
//             <div className="max-h-48 overflow-y-auto bg-gray-800 border border-gray-700 rounded-lg p-4 space-y-2">
//               {selectableRescuers.length > 0 ? (
//                 selectableRescuers.map(r => (
//                   <div key={r.username} className="flex items-center">
//                     <input
//                       type="checkbox"
//                       id={`member-${r.username}`}
//                       checked={selectedMembers.has(r.username)}
//                       onChange={() => handleMemberToggle(r.username)}
//                       className="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-600 rounded bg-gray-800"
//                     />
//                     <label htmlFor={`member-${r.username}`} className="ml-3 text-sm text-gray-300">
//                       {r.name} ({r.username})
//                     </label>
//                   </div>
//                 ))
//               ) : (
//                 <p className="text-gray-400 text-sm">No rescuers available to add.</p>
//               )}
//             </div>
//           </div>

//           <div className="flex gap-3 pt-4">
//             <button
//               type="button"
//               onClick={() => setIsTeamFormVisible(false)}
//               className="flex-1 bg-gray-700 hover:bg-gray-600 text-white py-2 px-4 rounded-lg transition-colors"
//             >
//               Cancel
//             </button>
//             <button
//               type="submit"
//               className="flex-1 bg-indigo-600 hover:bg-indigo-700 text-white py-2 px-4 rounded-lg transition-colors"
//             >
//               Save Team
//             </button>
//           </div>
//         </form>
//       </SlideInForm>
//     </div>
//   );
// };


// Map Dashboard Component (Simplified for demo)
// const MapDashboard = () => {
//   const [filters, setFilters] = useState({
//     users: true,
//     rescueTeams: true,
//     shelters: true,
//   });

//   const handleFilterChange = (event) => {
//     const { name, checked } = event.target;
//     setFilters(prevFilters => ({
//       ...prevFilters,
//       [name]: checked,
//     }));
//   };

//   return (
//     <div className="space-y-6">
//       <div className="flex items-center justify-between">
//         <div>
//           <h1 className="text-2xl font-bold text-white">Live Map</h1>
//           <p className="text-gray-400 mt-1">Real-time locations of users, teams, and shelters</p>
//         </div>
//       </div>

//       <div className="bg-gray-800 rounded-xl overflow-hidden" style={{ height: '70vh' }}>
//         {/* Filter Controls */}
//         <div className="absolute top-4 right-4 bg-gray-800 p-4 rounded-lg shadow-lg z-10 border border-gray-700">
//           <h3 className="text-lg font-semibold text-white mb-3">Map Filters</h3>
//           <div className="space-y-3">
//             <div className="flex items-center">
//               <input
//                 type="checkbox"
//                 id="users"
//                 name="users"
//                 checked={filters.users}
//                 onChange={handleFilterChange}
//                 className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-600 rounded bg-gray-800"
//               />
//               <label htmlFor="users" className="ml-3 text-sm font-medium text-gray-300">
//                 Users
//               </label>
//             </div>
//             <div className="flex items-center">
//               <input
//                 type="checkbox"
//                 id="rescueTeams"
//                 name="rescueTeams"
//                 checked={filters.rescueTeams}
//                 onChange={handleFilterChange}
//                 className="h-4 w-4 text-red-600 focus:ring-red-500 border-gray-600 rounded bg-gray-800"
//               />
//               <label htmlFor="rescueTeams" className="ml-3 text-sm font-medium text-gray-300">
//                 Rescue Teams
//               </label>
//             </div>
//             <div className="flex items-center">
//               <input
//                 type="checkbox"
//                 id="shelters"
//                 name="shelters"
//                 checked={filters.shelters}
//                 onChange={handleFilterChange}
//                 className="h-4 w-4 text-green-600 focus:ring-green-500 border-gray-600 rounded bg-gray-800"
//               />
//               <label htmlFor="shelters" className="ml-3 text-sm font-medium text-gray-300">
//                 Shelters
//               </label>
//             </div>
//           </div>
//         </div>

//         {/* Map Placeholder */}
//         <div className="w-full h-full bg-gray-700 flex items-center justify-center relative">
//           <div className="text-center">
//             <Map size={64} className="text-gray-500 mx-auto mb-4" />
//             <p className="text-gray-400 text-lg">Interactive Map Component</p>
//             <p className="text-gray-500 text-sm mt-2">
//               This would integrate with your existing MapContainer component<br />
//               showing real-time locations based on selected filters
//             </p>
//           </div>
//         </div>
//       </div>
//     </div>
//   );
// };

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
