// src/services/victimsService.js
const API_URL = 'http://localhost:5000/api/victims';

/**
 * Fetches all victims from the API.
 * @returns {Promise<Array>} A promise that resolves to an array of victims.
 */
export const getVictims = async () => {
    const response = await fetch(API_URL);
    if (!response.ok) {
        throw new Error('Failed to fetch victims');
    }
    return await response.json();
};
