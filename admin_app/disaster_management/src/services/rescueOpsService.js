const API_BASE = 'http://localhost:8000/api/rescue-ops/teams'; // adjust to your backend URL

export async function getRescueTeams() {
  const res = await fetch(`${API_BASE}`);
  if (!res.ok) throw new Error('Failed to fetch rescue teams');
  return res.json();
}

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
  return res.json();
}

export async function logRescueToShelter(data) {
  const res = await fetch(`${API_BASE}/log-rescue`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });
  if (!res.ok) throw new Error('Failed to log rescue');
  return res.json();
}

export async function autoAssignTeamToIncident(data) {
  const res = await fetch(`${API_BASE}/dispatch/auto`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });
  if (!res.ok) throw new Error('Failed to auto-assign team');
  return res.json();
}

export async function manualAssignTeam(teamId, incidentId) {
  const res = await fetch(`${API_BASE}/dispatch/manual`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ teamId, incidentId }),
  });
  if (!res.ok) throw new Error('Failed to manually assign team');
  return res.json();
}
