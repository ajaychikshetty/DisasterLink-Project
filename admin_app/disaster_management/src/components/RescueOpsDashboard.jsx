import React, { useState, useEffect, useCallback } from "react";
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

  const leader = rescuers.find((r) => r.id === team.leader);
  const members = team.members.map((id) => rescuers.find((r) => r.id === id));

  return (
    <SlideInForm
      isOpen={isOpen}
      onClose={onClose}
      title={`Team Members (${team.name})`}
    >
      <div className="space-y-4">
        {/* Leader */}
        {leader && (
          <div className="p-4 bg-gray-800 rounded-lg shadow-md">
            <p className="text-white font-semibold">Leader: {leader.name}</p>
            <p className="text-gray-400 text-sm">{leader.phone || "N/A"}</p>
            <span
              className={`inline-block mt-2 px-2 py-1 text-xs rounded-full ${
                leader.active
                  ? "bg-green-600 text-white"
                  : "bg-gray-600 text-gray-200"
              }`}
            >
              {leader.active ? "Active" : "Inactive"}
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
                        m.active
                          ? "bg-green-600 text-white"
                          : "bg-gray-600 text-gray-200"
                      }`}
                    >
                      {m.active ? "Active" : "Inactive"}
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

  const [selectedTeam, setSelectedTeam] = useState(null); // slide-in panel

  const [teamForm, setTeamForm] = useState({
    name: "",
    leader: "",
    members: [],
  });

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

  // --- Fetch Data
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

  // --- Reset & Save
  const resetForm = () => {
    setEditingTeam(null);
    setTeamForm({ teamName: "", leader: "", members: [] });
    setIsFormVisible(false);
  };

  const handleSaveTeam = async (e) => {
    e.preventDefault();
    try {
      if (editingTeam) {
        await rescueOpsService.updateRescueTeam(editingTeam.teamId, teamForm);
      } else {
        await rescueOpsService.createRescueTeam(teamForm);
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
      setDispatchForm({
        mode: "auto",
        incidentId: "",
        latitude: "",
        longitude: "",
        teamId: "",
      });
      loadAll();
    } catch (err) {
      setError(err.message);
    }
  };

  // --- UI Rendering
  if (loading)
    return (
      <div className="p-6 text-gray-400">Loading Rescue Operations...</div>
    );
  if (error)
    return (
      <div className="p-6 bg-red-900/50 border border-red-500 rounded-xl">
        <div className="flex items-center gap-2 text-red-400">
          <AlertCircle size={20} />
          <span>Error: {error}</span>
        </div>
      </div>
    );

  return (
    <div className="space-y-6 p-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">
            Rescue Operations Dashboard
          </h1>
          <p className="text-gray-400 mt-1">
            Manage rescue teams, assignments, and logs
          </p>
        </div>
        <button
          onClick={() => setIsFormVisible(true)}
          className="flex items-center gap-2 bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2 rounded-lg transition-colors"
        >
          <Plus size={16} />
          Add Team
        </button>
      </div>

      {/* Teams List */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {teams.map((t) => (
          <div
            key={t.teamId}
            className="bg-gray-800 rounded-xl p-6 hover:bg-gray-750 transition-colors"
          >
            {/* Header */}
            <div className="flex justify-between items-start mb-4">
              <div>
                <h3 className="text-lg font-semibold text-white">{t.teamName}</h3>
                <p className="text-sm text-gray-400">
                  Leader:{" "}
                  {rescuers.find((r) => r.id === t.leader)?.name || t.leader}
                </p>
              </div>
              <div className="flex gap-2">
                <button
                  onClick={() => {
                    setEditingTeam(t);
                    setTeamForm(t);
                    setIsFormVisible(true);
                  }}
                  className="text-indigo-400 hover:text-indigo-300"
                >
                  <Edit size={16} />
                </button>
                <button
                  onClick={() => handleDeleteTeam(t.teamId)}
                  className="text-red-400 hover:text-red-300"
                >
                  <Trash2 size={16} />
                </button>
                <button
                  onClick={() => setSelectedTeam(t)}
                  className="text-gray-400 hover:text-white"
                >
                  <Users size={16} />
                </button>
              </div>
            </div>

            {/* Members */}
            <div className="space-y-2 text-sm text-gray-400">
              <div className="flex items-center gap-1">
                <Users size={14} />
                <span>{t.members.length} Members</span>
              </div>
              <div className="flex items-center gap-1">
                <UserCheck size={14} />
                <span>Status: {t.status}</span>
              </div>
              <div className="flex items-center gap-1">
                <MapPin size={14} />
                <span>
                  Assigned: {t.assignedIncident ? t.assignedIncident : "None"}
                </span>
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Rescue Log Form */}
      <div className="bg-gray-800 rounded-xl p-6">
        <h2 className="text-lg font-semibold text-white mb-4">Log Rescue</h2>
        <form
          onSubmit={handleLogRescue}
          className="grid grid-cols-2 gap-3 text-gray-300"
        >
          <select
            value={rescueLogForm.shelterId}
            onChange={(e) =>
              setRescueLogForm({ ...rescueLogForm, shelterId: e.target.value })
            }
            className="col-span-2 bg-gray-700 text-white rounded p-2"
            required
          >
            <option value="">Select Shelter</option>
            {shelters.map((s) => (
              <option key={s.id} value={s.id}>
                {s.name}
              </option>
            ))}
          </select>
          {["total", "kids", "women", "men"].map((f) => (
            <input
              key={f}
              type="number"
              value={rescueLogForm[f]}
              onChange={(e) =>
                setRescueLogForm({
                  ...rescueLogForm,
                  [f]: Number(e.target.value),
                })
              }
              placeholder={f}
              className="bg-gray-700 text-white rounded p-2"
              min="0"
            />
          ))}
          <button
            type="submit"
            className="col-span-2 bg-blue-600 hover:bg-blue-700 text-white py-2 rounded-lg"
          >
            Log Rescue
          </button>
        </form>
      </div>

      {/* Dispatch Form */}
      <div className="bg-gray-800 rounded-xl p-6">
        <h2 className="text-lg font-semibold text-white mb-4">Dispatch Team</h2>
        <form
          onSubmit={handleDispatch}
          className="grid grid-cols-2 gap-3 text-gray-300"
        >
          <select
            value={dispatchForm.mode}
            onChange={(e) =>
              setDispatchForm({ ...dispatchForm, mode: e.target.value })
            }
            className="col-span-2 bg-gray-700 text-white rounded p-2"
          >
            <option value="auto">Auto Assign</option>
            <option value="manual">Manual Assign</option>
          </select>
          <input
            type="text"
            value={dispatchForm.incidentId}
            onChange={(e) =>
              setDispatchForm({ ...dispatchForm, incidentId: e.target.value })
            }
            placeholder="Incident ID"
            className="col-span-2 bg-gray-700 text-white rounded p-2"
            required
          />
          {dispatchForm.mode === "auto" ? (
            <>
              <input
                type="text"
                value={dispatchForm.latitude}
                onChange={(e) =>
                  setDispatchForm({
                    ...dispatchForm,
                    latitude: e.target.value,
                  })
                }
                placeholder="Latitude"
                className="bg-gray-700 text-white rounded p-2"
                required
              />
              <input
                type="text"
                value={dispatchForm.longitude}
                onChange={(e) =>
                  setDispatchForm({
                    ...dispatchForm,
                    longitude: e.target.value,
                  })
                }
                placeholder="Longitude"
                className="bg-gray-700 text-white rounded p-2"
                required
              />
            </>
          ) : (
            <select
              value={dispatchForm.teamId}
              onChange={(e) =>
                setDispatchForm({ ...dispatchForm, teamId: e.target.value })
              }
              className="col-span-2 bg-gray-700 text-white rounded p-2"
              required
            >
              <option value="">Select Team</option>
              {teams
                .filter((t) => t.status === "Free")
                .map((t) => (
                  <option key={t.teamId} value={t.teamId}>
                    {t.teamName}
                  </option>
                ))}
            </select>
          )}
          <button
            type="submit"
            className="col-span-2 bg-indigo-600 hover:bg-indigo-700 text-white py-2 rounded-lg"
          >
            Dispatch
          </button>
        </form>
      </div>

      {/* Slide-in Team Form */}
      <SlideInForm
        isOpen={isFormVisible}
        onClose={resetForm}
        title={editingTeam ? "Edit Team" : "Create New Team"}
      >
        <form onSubmit={handleSaveTeam} className="space-y-4">
          <input
            type="text"
            placeholder="Team Name"
            value={teamForm.teamName}
            onChange={(e) => setTeamForm({ ...teamForm, name: e.target.value })}
            className="w-full p-2 rounded bg-gray-700 text-white"
            required
          />
          <select
            value={teamForm.leader}
            onChange={(e) =>
              setTeamForm({ ...teamForm, leader: e.target.value })
            }
            className="w-full p-2 rounded bg-gray-700 text-white"
            required
          >
            <option value="">Select Leader</option>
            {rescuers.map((r) => (
              <option key={r.id} value={r.id}>
                {r.name}
              </option>
            ))}
          </select>
          <div>
            <p className="text-gray-400 mb-2">Select Members</p>
            <div className="grid grid-cols-2 gap-2">
              {rescuers.map((r) => (
                <label
                  key={r.id}
                  className="flex items-center gap-2 text-white"
                >
                  <input
                    type="checkbox"
                    checked={teamForm.members.includes(r.id)}
                    onChange={() => {
                      const members = teamForm.members.includes(r.id)
                        ? teamForm.members.filter((m) => m !== r.id)
                        : [...teamForm.members, r.id];
                      setTeamForm({ ...teamForm, members });
                    }}
                  />
                  {r.name}
                </label>
              ))}
            </div>
          </div>
          <button
            type="submit"
            className="w-full bg-green-600 hover:bg-green-700 text-white py-2 rounded-lg"
          >
            {editingTeam ? "Update Team" : "Create Team"}
          </button>
        </form>
      </SlideInForm>

      {/* Slide-in Team Members Panel */}
      <TeamMembersPanel
        isOpen={!!selectedTeam}
        onClose={() => setSelectedTeam(null)}
        team={selectedTeam}
        rescuers={rescuers}
      />
    </div>
  );
};

export default RescueOpsDashboard;
