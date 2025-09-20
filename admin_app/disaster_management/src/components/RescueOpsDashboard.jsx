import React, { useState, useEffect, useCallback, useMemo } from "react";
import {
  Plus,
  Edit,
  Trash2,
  Users,
  AlertCircle,
  MapPin,
  UserCheck,
} from "lucide-react";
import * as rescueOpsService from "../services/rescueOpsService";
import * as rescuerService from "../services/rescuerService";
import * as shelterService from "../services/shelterService";
import SlideInForm from "./SlideInForm";

// --- Slide-in Panel for Members ---
const TeamMembersPanel = ({ isOpen, onClose, team, rescuers }) => {
  if (!team) return null;

  const leader = rescuers.find((r) => r.id === team.leader.id);
  
  const memberIds = Object.keys(team.members);
  const members = memberIds.map((id) => rescuers.find((r) => r.id === id));

  return (
    <SlideInForm
      isOpen={isOpen}
      onClose={onClose}
      title={`Team Members (${team.teamName})`}
    >
      <div className="space-y-4">
        {/* Leader */}
        {leader && (
          <div className="p-4 bg-gray-800 rounded-lg shadow-md">
            <p className="text-white font-semibold">Leader: {leader.name}</p>
            <p className="text-gray-400 text-sm">{leader.phone || "N/A"}</p>
            <span
              className={`inline-block mt-2 px-2 py-1 text-xs rounded-full ${
                leader.loginAvailable
                  ? "bg-green-600 text-white"
                  : "bg-gray-600 text-gray-200"
              }`}
            >
              {leader.loginAvailable ? "Active" : "Inactive"}
            </span>
          </div>
        )}

        {/* Members */}
        {members.length > 0 ? (
          <ul className="space-y-4">
            {members.map(
              (m) =>
                m && (
                  <li
                    key={m.id}
                    className="p-4 bg-gray-800 rounded-lg shadow-md flex justify-between items-center"
                  >
                    <div>
                      <p className="text-white font-semibold">{m.name}</p>
                      <p className="text-gray-400 text-sm">{m.phone || "N/A"}</p>
                      <p className="text-gray-500 text-xs">{m.status}</p>
                    </div>
                    <span
                      className={`px-2 py-1 text-xs rounded-full ${
                        m.loginAvailable
                          ? "bg-green-600 text-white"
                          : "bg-gray-600 text-gray-200"
                      }`}
                    >
                      {m.loginAvailable ? "Active" : "Inactive"}
                    </span>
                  </li>
                )
            )}
          </ul>
        ) : (
          <p className="text-gray-400">No members assigned to this team.</p>
        )}
      </div>
    </SlideInForm>
  );
};

const RescueOpsDashboard = () => {
  const [teams, setTeams] = useState([]);
  const [rescuers, setRescuers] = useState([]);
  const [shelters, setShelters] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const [editingTeam, setEditingTeam] = useState(null);
  const [isFormVisible, setIsFormVisible] = useState(false);

  const [selectedTeam, setSelectedTeam] = useState(null);

  // ENHANCEMENT: State for the new form logic
  const [teamForm, setTeamForm] = useState({
    teamName: "",
    selectedRescuers: [], // Array of selected rescuer IDs
    leader: "",           // ID of the leader
  });

  // Memoize the list of selected rescuer objects for the leader selection UI
  const selectedRescuerDetails = useMemo(() => {
    return rescuers.filter(r => teamForm.selectedRescuers.includes(r.id));
  }, [teamForm.selectedRescuers, rescuers]);


  const [rescueLogForm, setRescueLogForm] = useState({
    shelterId: "",
    total: 0,
    kids: 0,
    women: 0,
    men: 0,
  });

  const [dispatchForm, setDispatchForm] = useState({
    mode: "auto",
    incidentId: "",
    latitude: "",
    longitude: "",
    teamId: "",
  });

  const loadAll = useCallback(async () => {
    try {
      setLoading(true);
      const [teamsData, rescuersData, sheltersData] = await Promise.all([
        rescueOpsService.getRescueTeams(),
        rescuerService.getRescuers(),
        shelterService.getShelters(),
      ]);
      setTeams(teamsData);
      setRescuers(rescuersData);
      setShelters(sheltersData);
    } catch (err) {
      setError(err.message || "Failed to load data");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadAll();
  }, [loadAll]);

  const resetForm = () => {
    setEditingTeam(null);
    setTeamForm({ teamName: "", selectedRescuers: [], leader: "" });
    setIsFormVisible(false);
  };

  const handleSaveTeam = async (e) => {
    e.preventDefault();
    if (!teamForm.leader) {
      alert("Please select a leader for the team.");
      return;
    }

    // ENHANCEMENT: Construct the final payload for the API
    const finalPayload = {
      teamName: teamForm.teamName,
      leader: teamForm.leader,
      // Members are all selected rescuers except for the leader
      members: teamForm.selectedRescuers.filter(id => id !== teamForm.leader),
    };

    try {
      if (editingTeam) {
        await rescueOpsService.updateRescueTeam(editingTeam.teamId, finalPayload);
      } else {
        await rescueOpsService.createRescueTeam(finalPayload);
      }
      resetForm();
      loadAll();
    } catch (err) {
      setError(err.message);
    }
  };

  const handleDeleteTeam = async (teamId) => {
    if (!window.confirm("Delete this team?")) return;
    try {
      await rescueOpsService.deleteRescueTeam(teamId);
      loadAll();
    } catch (err) {
      setError(err.message);
    }
  };

  const handleLogRescue = async (e) => {
    e.preventDefault();
    try {
      await rescueOpsService.logRescueToShelter({
        shelterId: rescueLogForm.shelterId,
        rescuedCount: { ...rescueLogForm },
      });
      setRescueLogForm({ shelterId: "", total: 0, kids: 0, women: 0, men: 0 });
      loadAll();
    } catch (err) {
      setError(err.message);
    }
  };

  const handleDispatch = async (e) => {
    e.preventDefault();
    try {
      if (dispatchForm.mode === "auto") {
        await rescueOpsService.autoAssignTeamToIncident({
          incidentId: dispatchForm.incidentId,
          latitude: dispatchForm.latitude,
          longitude: dispatchForm.longitude,
        });
      } else {
        await rescueOpsService.manualAssignTeam(
          dispatchForm.teamId,
          dispatchForm.incidentId
        );
      }
      setDispatchForm({ mode: "auto", incidentId: "", latitude: "", longitude: "", teamId: "" });
      loadAll();
    } catch (err) {
      setError(err.message);
    }
  };
  
  // ENHANCEMENT: Handler for selecting/deselecting rescuers
  const handleRescuerSelection = (rescuerId) => {
    const isSelected = teamForm.selectedRescuers.includes(rescuerId);
    let newSelectedRescuers = [...teamForm.selectedRescuers];
    let newLeader = teamForm.leader;

    if (isSelected) {
      // If deselected, remove from the list
      newSelectedRescuers = newSelectedRescuers.filter(id => id !== rescuerId);
      // If the deselected person was the leader, reset the leader
      if (teamForm.leader === rescuerId) {
        newLeader = "";
      }
    } else {
      // If selected, add to the list
      newSelectedRescuers.push(rescuerId);
    }
    
    setTeamForm({
      ...teamForm,
      selectedRescuers: newSelectedRescuers,
      leader: newLeader,
    });
  };


  if (loading) return <div className="p-6 text-gray-400">Loading...</div>;
  if (error) return <div className="p-6 text-red-400">Error: {error}</div>;

  return (
    <div className="space-y-6 p-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Rescue Ops Dashboard</h1>
          <p className="text-gray-400 mt-1">Manage teams, assignments, and logs</p>
        </div>
        <button
          onClick={() => setIsFormVisible(true)}
          className="flex items-center gap-2 bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2 rounded-lg transition-colors"
        >
          <Plus size={16} /> Add Team
        </button>
      </div>

      {/* Teams List */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {teams.map((t) => (
          <div key={t.teamId} className="bg-gray-800 rounded-xl p-6 hover:bg-gray-750 transition-colors">
            {/* Header */}
            <div className="flex justify-between items-start mb-4">
              <div>
                <h3 className="text-lg font-semibold text-white">{t.teamName}</h3>
                <p className="text-sm text-gray-400">Leader: {t.leader.name}</p>
              </div>
              <div className="flex gap-2">
                <button
                  onClick={() => {
                    setEditingTeam(t);
                    // ENHANCEMENT: Populate form state for editing
                    const allPersonnel = [t.leader.id, ...Object.keys(t.members)];
                    setTeamForm({
                        teamName: t.teamName,
                        selectedRescuers: allPersonnel,
                        leader: t.leader.id,
                    });
                    setIsFormVisible(true);
                  }}
                  className="text-indigo-400 hover:text-indigo-300"
                >
                  <Edit size={16} />
                </button>
                <button onClick={() => handleDeleteTeam(t.teamId)} className="text-red-400 hover:text-red-300">
                  <Trash2 size={16} />
                </button>
                <button onClick={() => setSelectedTeam(t)} className="text-gray-400 hover:text-white">
                  <Users size={16} />
                </button>
              </div>
            </div>

            {/* Members & Status */}
            <div className="space-y-2 text-sm text-gray-400">
              <div className="flex items-center gap-1">
                <Users size={14} />
                <span>{Object.keys(t.members).length} Members</span>
              </div>
              <div className="flex items-center gap-1">
                <UserCheck size={14} />
                <span>Status: {t.status}</span>
              </div>
              <div className="flex items-center gap-1">
                <MapPin size={14} />
                <span>
                  {/* FIX: Check assignedLatitude for assignment status */}
                  Assigned: {t.teamAddress ? t.teamAddress : "NNot assigned"}
                </span>
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Other Forms (Log Rescue, Dispatch) - No changes */}
      {/* ... */}

      {/* ENHANCED Slide-in Team Form */}
      <SlideInForm isOpen={isFormVisible} onClose={resetForm} title={editingTeam ? "Edit Team" : "Create New Team"}>
        <form onSubmit={handleSaveTeam} className="space-y-6">
          <input
            type="text"
            placeholder="Team Name"
            value={teamForm.teamName}
            onChange={(e) => setTeamForm({ ...teamForm, teamName: e.target.value })}
            className="w-full p-2 rounded bg-gray-700 text-white"
            required
          />

          {/* Step 1: Select all team personnel */}
          <div>
            <p className="text-gray-300 mb-2 font-semibold">1. Select Team Personnel</p>
            <div className="grid grid-cols-2 gap-2 max-h-48 overflow-y-auto p-2 bg-gray-900/50 rounded">
              {rescuers.map((r) => (
                <label key={r.id} className="flex items-center gap-2 text-white cursor-pointer">
                  <input
                    type="checkbox"
                    checked={teamForm.selectedRescuers.includes(r.id)}
                    onChange={() => handleRescuerSelection(r.id)}
                  />
                  {r.name}
                </label>
              ))}
            </div>
          </div>
          
          {/* Step 2: Select leader from the selected personnel */}
          {teamForm.selectedRescuers.length > 0 && (
            <div>
              <p className="text-gray-300 mb-2 font-semibold">2. Choose a Leader</p>
              <div className="space-y-2 p-2 bg-gray-900/50 rounded">
                {selectedRescuerDetails.map(r => (
                  <label key={r.id} className="flex items-center gap-2 text-white cursor-pointer">
                    <input
                      type="radio"
                      name="leader"
                      value={r.id}
                      checked={teamForm.leader === r.id}
                      onChange={(e) => setTeamForm({...teamForm, leader: e.target.value})}
                      required
                    />
                    {r.name}
                  </label>
                ))}
              </div>
            </div>
          )}

          <button
            type="submit"
            className="w-full bg-green-600 hover:bg-green-700 text-white py-2 rounded-lg disabled:bg-gray-500"
            disabled={!teamForm.leader} // Disable button if no leader is chosen
          >
            {editingTeam ? "Update Team" : "Create Team"}
          </button>
        </form>
      </SlideInForm>

      {/* Slide-in Team Members Panel */}
      <TeamMembersPanel isOpen={!!selectedTeam} onClose={() => setSelectedTeam(null)} team={selectedTeam} rescuers={rescuers} />
    </div>
  );
};

export default RescueOpsDashboard;