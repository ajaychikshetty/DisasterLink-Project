// The base URL for your FastAPI backend's messages endpoints
const API_URL = 'http://localhost:5000/api/messages/';

/**
 * Fetches all messages from the API.
 * @returns {Promise<Array>} A promise that resolves to an array of messages.
 */
export const getMessages = async () => {
    const response = await fetch(API_URL);
    if (!response.ok) {
        throw new Error('Failed to fetch messages');
    }
    return await response.json();
};

/**
 * Fetches a single message by its ID.
 * @param {string} messageId - The ID of the message to fetch.
 * @returns {Promise<Object>} A promise that resolves to the message object.
 */
export const getMessageById = async (messageId) => {
    const response = await fetch(`${API_URL}/${messageId}`);
    if (!response.ok) {
        throw new Error('Failed to fetch message');
    }
    return await response.json();
};
