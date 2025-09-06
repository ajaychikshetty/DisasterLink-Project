const API_URL = 'http://localhost:8000/api/map/coverage';

/**
 * Fetches all users, rescue teams, and shelters within a given map bounds.
 * @param {object} bounds - A Leaflet bounds object with _southWest and _northEast coordinates.
 * @returns {Promise<object>} A promise that resolves to the map coverage data.
 */
export const getMapCoverage = async (bounds) => {
    // Construct the URL with query parameters from the bounds
    const params = new URLSearchParams({
        min_lat: bounds._southWest.lat,
        min_lon: bounds._southWest.lng,
        max_lat: bounds._northEast.lat,
        max_lon: bounds._northEast.lng,
    });

    const response = await fetch(`${API_URL}?${params.toString()}`);

    if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.detail || 'Failed to fetch map data');
    }
    
    return await response.json();
};