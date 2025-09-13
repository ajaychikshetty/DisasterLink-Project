
const API_BASE_URL = 'http://localhost:8000/api';


/**
 * Sends a disaster alert to a list of phone numbers.
 * @param {string} disasterName - The alert message content.
 * @param {string[]} numbers - An array of phone numbers (extracted from user messages).
 * @returns {Promise<Object>} A promise that resolves to the API response.
 */
export const sendDisasterAlert = async (disasterName, numbers) => {
    const response = await fetch(`${API_BASE_URL}/disaster_alert`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({
            disaster_name: disasterName,
            numbers: numbers,
        }),
    });

    if (!response.ok) {
        const errorData = await response.json().catch(() => ({ detail: 'Failed to send alert and could not parse error response.' }));
        throw new Error(errorData.detail || 'Failed to send disaster alert');
    }

    return await response.json();
};