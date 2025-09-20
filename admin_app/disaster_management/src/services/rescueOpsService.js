// src/services/rescueOpsService.js

const API_BASE = 'http://localhost:5000/api/rescue-ops/teams'; // adjust to your backend URL

export async function getRescueTeams() {
  const res = await fetch(`${API_BASE}`);
  if (!res.ok) throw new Error('Failed to fetch rescue teams');
  return res.json();
}

// --- NEW: Assign a team to a location ---
export async function assignTeam(teamId, latitude, longitude) {
  const res = await fetch(`${API_BASE}/${teamId}/assign`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ latitude, longitude }),
  });
  if (!res.ok) {
    const errorData = await res.json().catch(() => ({ detail: 'Failed to assign team' }));
    throw new Error(errorData.detail || 'Failed to assign team');
  }
  return res.json();
}

// --- NEW: Unassign a team ---
export async function unassignTeam(teamId) {
  const res = await fetch(`${API_BASE}/${teamId}/unassign`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
  });
  if (!res.ok) {
    const errorData = await res.json().catch(() => ({ detail: 'Failed to unassign team' }));
    throw new Error(errorData.detail || 'Failed to unassign team');
  }
  return res.json();
}


// --- Existing functions below (assuming you have them) ---

export async function createRescueTeam(data) {
  const res = await fetch(`${API_BASE}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });
  if (!res.ok) throw new Error('Failed to create team');
  return res.json();
}

export async function updateRescueTeam(teamId, data) {
  const res = await fetch(`${API_BASE}/${teamId}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });
  if (!res.ok) throw new Error('Failed to update team');
  return res.json();
}

export async function deleteRescueTeam(teamId) {
  const res = await fetch(`${API_BASE}/${teamId}`, { method: 'DELETE' });
  if (!res.ok) throw new Error('Failed to delete team');
  return []; // DELETE often returns 204 No Content
}