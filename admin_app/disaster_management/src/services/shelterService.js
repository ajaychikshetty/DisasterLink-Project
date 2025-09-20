const API_URL = 'http://localhost:5000/api/shelters';

// Fetch all shelters
export const getShelters = async () => {
  const response = await fetch(API_URL);
  if (!response.ok) throw new Error('Failed to fetch shelters');
  return await response.json();
};

// Fetch one shelter
export const getShelterById = async (shelterId) => {
  const response = await fetch(`${API_URL}/${shelterId}`);
  if (!response.ok) throw new Error('Failed to fetch shelter');
  return await response.json();
};

// Create
export const createShelter = async (shelterData) => {
  const response = await fetch(API_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(shelterData),
  });
  if (!response.ok) {
    const errorData = await response.json();
    throw new Error(errorData.detail || 'Failed to create shelter');
  }
  return await response.json();
};

// Update
export const updateShelter = async (shelterId, shelterData) => {
  const response = await fetch(`${API_URL}/${shelterId}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(shelterData),
  });
  if (!response.ok) {
    const errorData = await response.json();
    throw new Error(errorData.detail || 'Failed to update shelter');
  }
  return await response.json();
};

// Delete
export const deleteShelter = async (shelterId) => {
  const response = await fetch(`${API_URL}/${shelterId}`, { method: 'DELETE' });
  if (!response.ok) {
    const errorData = await response.json();
    throw new Error(errorData.detail || 'Failed to delete shelter');
  }
  return await response.json();
};

// Add member
export const addMemberToShelter = async (shelterId, memberId) => {
  const response = await fetch(`${API_URL}/${shelterId}/add-member/${memberId}`, {
    method: 'POST',
  });
  if (!response.ok) {
    const errorData = await response.json();
    throw new Error(errorData.detail || 'Failed to add member');
  }
  return await response.json();
};

// Remove member
export const removeMemberFromShelter = async (shelterId, memberId) => {
  const response = await fetch(`${API_URL}/${shelterId}/remove-member/${memberId}`, {
    method: 'POST',
  });
  if (!response.ok) {
    const errorData = await response.json();
    throw new Error(errorData.detail || 'Failed to remove member');
  }
  return await response.json();
};
