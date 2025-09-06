// The base URL for your FastAPI backend's rescuer endpoints
const API_URL = 'http://localhost:8000/api/rescuemembers';

/**
 * Fetches all rescuers from the API.
 * @returns {Promise<Array>} A promise that resolves to an array of rescuers.
 */
export const getRescuers = async () => {
    const response = await fetch(API_URL);
    if (!response.ok) {
        throw new Error('Failed to fetch rescuers');
    }
    return await response.json();
};

/**
 * Creates a new rescuer.
 * @param {Object} rescuerData - The data for the new rescuer.
 * @returns {Promise<Object>} A promise that resolves to the newly created rescuer object.
 */
export const createRescuer = async (rescuerData) => {
    const response = await fetch(API_URL, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(rescuerData),
    });
    if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.detail || 'Failed to create rescuer');
    }
    return await response.json();
};

/**
 * Updates an existing rescuer.
 * @param {string} username - The username of the rescuer to update.
 * @param {Object} rescuerData - The updated data for the rescuer.
 * @returns {Promise<Object>} A promise that resolves to the updated rescuer object.
 */
export const updateRescuer = async (username, rescuerData) => {
    const response = await fetch(`${API_URL}/${username}`, {
        method: 'PUT',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(rescuerData),
    });
    if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.detail || 'Failed to update rescuer');
    }
    return await response.json();
};

/**
 * Deletes a rescuer by their username.
 * @param {string} username - The username of the rescuer to delete.
 * @returns {Promise<Object>} A promise that resolves to the deletion confirmation message.
 */
export const deleteRescuer = async (username) => {
    const response = await fetch(`${API_URL}/${username}`, {
        method: 'DELETE',
    });
    if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.detail || 'Failed to delete rescuer');
    }
    return await response.json();
};