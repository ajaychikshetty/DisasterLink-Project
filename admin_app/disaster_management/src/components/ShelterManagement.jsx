import React, { useState, useEffect, useCallback } from "react";
import axios from "axios";
import {
  Plus,
  Building,
  MapPin,
  Edit,
  Trash2,
  AlertCircle,
  Users,
} from "lucide-react";
import * as shelterService from "../services/shelterService";
import SlideInForm from "./SlideInForm";
import * as userService from "../services/userService";
import Autosuggest from "react-autosuggest";

// Shelter Occupants Panel (unchanged)
const ShelterOccupantsPanel = ({ isOpen, onClose, shelter }) => {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (isOpen && shelter?.rescuedMembers?.length) {
      setLoading(true);
      Promise.all(
        shelter.rescuedMembers.map((userId) => userService.getUser(userId))
      )
        .then((results) => setUsers(results))
        .finally(() => setLoading(false));
    } else {
      setUsers([]);
    }
  }, [isOpen, shelter]);

  return (
    <SlideInForm
      isOpen={isOpen}
      onClose={onClose}
      title={`Shelter Occupants (${shelter?.name || ""})`}
    >
      {loading ? (
        <p className="text-gray-400">Loading users...</p>
      ) : users.length === 0 ? (
        <p className="text-gray-400">No users in this shelter.</p>
      ) : (
        <ul className="space-y-4">
          {users.map((user) => (
            <li
              key={user.id}
              className="p-4 bg-gray-800 rounded-lg shadow-md flex justify-between items-center"
            >
              <div>
                <p className="text-white font-semibold">{user.fullName}</p>
                <p className="text-gray-400 text-sm">{user.phone}</p>
                <p className="text-gray-500 text-xs">{user.status}</p>
              </div>
              <span
                className={`px-2 py-1 text-xs rounded-full ${
                  user.active ? "bg-green-600 text-white" : "bg-gray-600 text-gray-200"
                }`}
              >
                {user.active ? "Active" : "Inactive"}
              </span>
            </li>
          ))}
        </ul>
      )}
    </SlideInForm>
  );
};

// Address input with OpenStreetMap autocomplete
const AddressInput = ({ formData, setFormData }) => {
  const [suggestions, setSuggestions] = useState([]);

  const fetchSuggestions = async (value) => {
    if (!value) {
      setSuggestions([]);
      return;
    }

    try {
      const res = await axios.get(
        `https://nominatim.openstreetmap.org/search?countrycodes=IN&q=${encodeURIComponent(
          value
        )}&format=json&addressdetails=1&limit=5`
      );
      setSuggestions(res.data);
    } catch (err) {
      console.error(err);
    }
  };

  const getSuggestionValue = (suggestion) => suggestion.display_name;

  const onSuggestionSelected = (event, { suggestion }) => {
    setFormData({
      ...formData,
      address: suggestion.display_name,
      latitude: suggestion.lat,
      longitude: suggestion.lon,
    });
  };

  const onSuggestionsClearRequested = () => setSuggestions([]);

  const inputProps = {
    placeholder: "Enter address",
    value: formData.address,
    onChange: (e, { newValue }) =>
      setFormData({ ...formData, address: newValue }),
    className: "w-full p-2 rounded bg-gray-700 text-white",
  };

  const theme = {
    container: { position: "relative" },
    suggestionsContainer: "absolute z-10 bg-gray-800 rounded shadow-lg w-full",
    suggestion: "p-2 cursor-pointer text-white hover:bg-gray-600 flex justify-between items-center",
    suggestionHighlighted: "bg-gray-600",
  };

  return (
    <Autosuggest
      suggestions={suggestions}
      onSuggestionsFetchRequested={({ value }) => fetchSuggestions(value)}
      onSuggestionsClearRequested={onSuggestionsClearRequested}
      getSuggestionValue={getSuggestionValue}
      renderSuggestion={(suggestion) => (
        <div className="flex justify-between items-center">
          <span>{suggestion.display_name}</span>
          <span className="text-gray-400">&#8594;</span>
        </div>
      )}
      onSuggestionSelected={onSuggestionSelected}
      inputProps={inputProps}
      theme={theme}
    />
  );
};

// Main Shelter Management Component
const ShelterManagement = () => {
  const [shelters, setShelters] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);
  const [isFormVisible, setIsFormVisible] = useState(false);
  const [editingShelter, setEditingShelter] = useState(null);
  const [selectedShelter, setSelectedShelter] = useState(null);

  const [formData, setFormData] = useState({
    name: "",
    capacity: "",
    latitude: "",
    longitude: "",
    address: "",
    contactNumber: "",
    description: "",
    amenities: "",
  });

  const fetchShelters = useCallback(async () => {
    try {
      setIsLoading(true);
      const data = await shelterService.getShelters();
      setShelters(data);
    } catch (err) {
      setError(err.message);
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchShelters();
  }, [fetchShelters]);

  useEffect(() => {
    if (editingShelter) {
      setFormData({
        name: editingShelter.name || "",
        capacity: editingShelter.capacity || "",
        latitude: editingShelter.latitude || "",
        longitude: editingShelter.longitude || "",
        address: editingShelter.address || "",
        contactNumber: editingShelter.contactNumber || "",
        description: editingShelter.description || "",
        amenities: (editingShelter.amenities || []).join(", "),
      });
    } else {
      setFormData({
        name: "",
        capacity: "",
        latitude: "",
        longitude: "",
        address: "",
        contactNumber: "",
        description: "",
        amenities: "",
      });
    }
  }, [editingShelter]);

  const handleSaveShelter = async (e) => {
    e.preventDefault();
    try {
      const shelterData = {
        name: formData.name,
        capacity: parseInt(formData.capacity, 10) || 0,
        latitude: parseFloat(formData.latitude),
        longitude: parseFloat(formData.longitude),
        address: formData.address,
        contactNumber: formData.contactNumber,
        description: formData.description,
        amenities: formData.amenities
          .split(",")
          .map((a) => a.trim())
          .filter(Boolean),
      };

      if (editingShelter) {
        await shelterService.updateShelter(editingShelter.id, shelterData);
      } else {
        await shelterService.createShelter(shelterData);
      }

      setIsFormVisible(false);
      setEditingShelter(null);
      fetchShelters();
    } catch (err) {
      setError(err.message);
    }
  };

  const handleDeleteShelter = async (shelterId) => {
    if (window.confirm("Are you sure you want to delete this shelter?")) {
      try {
        await shelterService.deleteShelter(shelterId);
        fetchShelters();
      } catch (err) {
        setError(err.message);
      }
    }
  };

  return (
    <div className="space-y-6 p-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Shelter Management</h1>
          <p className="text-gray-400 mt-1">
            Manage emergency shelters and their capacity
          </p>
        </div>
        <button
          onClick={() => {
            setEditingShelter(null);
            setIsFormVisible(true);
          }}
          className="flex items-center gap-2 bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2 rounded-lg transition-colors"
        >
          <Plus size={16} />
          Add Shelter
        </button>
      </div>

      {/* Loading and Error */}
      {isLoading && (
        <div className="bg-gray-800 rounded-xl p-8 text-center">
          <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-500"></div>
          <p className="text-gray-400 mt-2">Loading shelters...</p>
        </div>
      )}
      {error && (
        <div className="bg-red-900/50 border border-red-500 rounded-xl p-4">
          <div className="flex items-center gap-2 text-red-400">
            <AlertCircle size={20} />
            <span>Error: {error}</span>
          </div>
        </div>
      )}

      {/* Shelter list */}
      {!isLoading && !error && (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {shelters.map((shelter) => (
            <div
              key={shelter.id}
              className="bg-gray-800 rounded-xl p-6 hover:bg-gray-750 transition-colors"
            >
              <div className="flex items-start justify-between mb-4">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 bg-green-600 rounded-full flex items-center justify-center">
                    <Building size={20} className="text-white" />
                  </div>
                  <div>
                    <h3 className="text-lg font-semibold text-white">
                      {shelter.name}
                    </h3>
                    <p className="text-sm text-gray-400">{shelter.address}</p>
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  <button
                    onClick={() => {
                      setEditingShelter(shelter);
                      setIsFormVisible(true);
                    }}
                    className="text-indigo-400 hover:text-indigo-300"
                  >
                    <Edit size={16} />
                  </button>
                  <button
                    onClick={() => handleDeleteShelter(shelter.id)}
                    className="text-red-400 hover:text-red-300"
                  >
                    <Trash2 size={16} />
                  </button>
                  <button
                    onClick={() => setSelectedShelter(shelter)}
                    className="text-gray-400 hover:text-white"
                  >
                    <Users size={16} />
                  </button>
                </div>
              </div>
              <div className="space-y-3">
                <div className="flex justify-between items-center">
                  <span className="text-gray-400">Occupancy</span>
                  <span className="text-white font-medium">
                    {shelter.currentOccupancy || 0} / {shelter.capacity}
                  </span>
                </div>
                <div className="w-full bg-gray-700 rounded-full h-2">
                  <div
                    className="bg-green-500 h-2 rounded-full transition-all duration-300"
                    style={{
                      width: `${
                        (shelter.currentOccupancy / shelter.capacity) * 100
                      }%`,
                    }}
                  ></div>
                </div>
                <div className="flex items-center gap-1 text-gray-400 text-sm">
                  <MapPin size={12} />
                  <span>
                    {shelter.latitude?.toFixed(4)}, {shelter.longitude?.toFixed(4)}
                  </span>
                </div>
                <p className="text-sm text-gray-400">📞 {shelter.contactNumber}</p>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Slide-in form */}
      <SlideInForm
        isOpen={isFormVisible}
        onClose={() => setIsFormVisible(false)}
        title={editingShelter ? "Edit Shelter" : "Create New Shelter"}
      >
        <form onSubmit={handleSaveShelter} className="space-y-4">
          <input
            type="text"
            placeholder="Shelter Name"
            value={formData.name}
            onChange={(e) =>
              setFormData({ ...formData, name: e.target.value })
            }
            className="w-full p-2 rounded bg-gray-700 text-white"
            required
          />
          <input
            type="number"
            placeholder="Capacity"
            value={formData.capacity}
            onChange={(e) =>
              setFormData({ ...formData, capacity: e.target.value })
            }
            className="w-full p-2 rounded bg-gray-700 text-white"
            required
          />
          <AddressInput formData={formData} setFormData={setFormData} />
          <input
            type="text"
            placeholder="Contact Number"
            value={formData.contactNumber}
            onChange={(e) =>
              setFormData({ ...formData, contactNumber: e.target.value })
            }
            className="w-full p-2 rounded bg-gray-700 text-white"
          />
          <textarea
            placeholder="Description"
            value={formData.description}
            onChange={(e) =>
              setFormData({ ...formData, description: e.target.value })
            }
            className="w-full p-2 rounded bg-gray-700 text-white"
            rows={3}
          />
          <input
            type="text"
            placeholder="Amenities (comma separated)"
            value={formData.amenities}
            onChange={(e) =>
              setFormData({ ...formData, amenities: e.target.value })
            }
            className="w-full p-2 rounded bg-gray-700 text-white"
          />
          <button
            type="submit"
            className="w-full bg-indigo-600 hover:bg-indigo-700 text-white py-2 rounded-lg"
          >
            {editingShelter ? "Update Shelter" : "Create Shelter"}
          </button>
        </form>
      </SlideInForm>

      {/* Slide-in occupants panel */}
      <ShelterOccupantsPanel
        isOpen={!!selectedShelter}
        onClose={() => setSelectedShelter(null)}
        shelter={selectedShelter}
      />
    </div>
  );
};

export default ShelterManagement;

