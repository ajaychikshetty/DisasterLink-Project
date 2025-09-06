// The base URL for your FastAPI backend
const API_URL = 'http://localhost:8000/api/users';

/**
 * Fetches all users from the API.
 * @returns {Promise<Array>} A promise that resolves to an array of users.
 */
export const getUsers = async () => {
    const response = await fetch(API_URL);
    if (!response.ok) {
        throw new Error('Failed to fetch users');
    }
    return await response.json();
};

/**
 * Fetches a single user by their ID.
 * @param {string} userId - The ID of the user to fetch.
 * @returns {Promise<Object>} A promise that resolves to the user object.
 */
export const getUserById = async (userId) => {
    const response = await fetch(`${API_URL}/${userId}`);
    if (!response.ok) {
        throw new Error('Failed to fetch user');
    }
    return await response.json();
};

/**
 * Creates a new user.
 * @param {Object} userData - The data for the new user.
 * @returns {Promise<Object>} A promise that resolves to the newly created user object.
 */
export const createUser = async (userData) => {
    const response = await fetch(API_URL, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(userData),
    });
    if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.detail || 'Failed to create user');
    }
    return await response.json();
};

/**
 * Updates an existing user.
 * @param {string} userId - The ID of the user to update.
 * @param {Object} userData - The updated data for the user.
 * @returns {Promise<Object>} A promise that resolves to the updated user object.
 */
export const updateUser = async (userId, userData) => {
    const response = await fetch(`${API_URL}/${userId}`, {
        method: 'PUT',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(userData),
    });
    if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.detail || 'Failed to update user');
    }
    return await response.json();
};

/**
 * Deletes a user by their ID.
 * @param {string} userId - The ID of the user to delete.
 * @returns {Promise<Object>} A promise that resolves to the deletion confirmation message.
 */
export const deleteUser = async (userId) => {
    const response = await fetch(`${API_URL}/${userId}`, {
        method: 'DELETE',
    });
    if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.detail || 'Failed to delete user');
    }
    return await response.json();
};