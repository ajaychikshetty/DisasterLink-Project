import React, { useState, useEffect, useCallback } from "react";
import * as userService from "../services/userService";
import {
  X,
  Plus,
  User,
  MapPin,
  Phone,
  Edit,
  Trash2,
  AlertCircle,
} from "lucide-react";
import SlideInForm from "./SlideInForm";

// User Management Component
const UserManagement = () => {
  const [users, setUsers] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);
  const [isFormVisible, setIsFormVisible] = useState(false);
  const [editingUser, setEditingUser] = useState(null);
  const [formData, setFormData] = useState({
    name: "",
    dob: "",
    gender: "",
    contactNo: "",
    city: "",
    bloodGroup: "",
    latitude: "",
    longitude: "",
  });

  // fetch users
  const fetchUsers = useCallback(async () => {
    try {
      setIsLoading(true);
      const data = await userService.getUsers();
      setUsers(data);
    } catch (err) {
      setError(err.message);
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchUsers();
  }, [fetchUsers]);

  // sync form data when editing
  useEffect(() => {
    if (editingUser) {
      setFormData({
        name: editingUser.name || "",
        dob: editingUser.dob || "",
        gender: editingUser.gender || "",
        contactNo: editingUser.contactNo || "",
        city: editingUser.city || "",
        bloodGroup: editingUser.bloodGroup || "",
        latitude: editingUser.location?.latitude || "",
        longitude: editingUser.location?.longitude || "",
      });
    } else {
      setFormData({
        name: "",
        dob: "",
        gender: "",
        contactNo: "",
        city: "",
        bloodGroup: "",
        latitude: "",
        longitude: "",
      });
    }
  }, [editingUser]);

  // save user
  const handleSaveUser = async (e) => {
    e.preventDefault();
    try {
      const userData = {
        ...formData,
        location: {
          latitude: parseFloat(formData.latitude),
          longitude: parseFloat(formData.longitude),
        },
      };
      delete userData.latitude;
      delete userData.longitude;

      if (editingUser) {
        await userService.updateUser(editingUser.userId, userData);
      } else {
        await userService.createUser(userData);
      }
      setIsFormVisible(false);
      setEditingUser(null);
      fetchUsers();
    } catch (err) {
      setError(err.message);
    }
  };

  // delete user
  const handleDeleteUser = async (userId) => {
    if (window.confirm("Are you sure you want to delete this user?")) {
      try {
        await userService.deleteUser(userId);
        fetchUsers();
      } catch (err) {
        setError(err.message);
      }
    }
  };

  return (
    <div className="space-y-6 p-6 min-h-screen">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">User Management</h1>
          <p className="text-gray-400 mt-1">
            Manage registered users and their information
          </p>
        </div>
        <button
          onClick={() => {
            setEditingUser(null);
            setIsFormVisible(true);
          }}
          className="flex items-center gap-2 bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2 rounded-lg transition-colors"
        >
          <Plus size={16} />
          Add User
        </button>
      </div>

      {/* Loading state */}
      {isLoading && (
        <div className="bg-gray-800 rounded-xl p-8 text-center">
          <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-500"></div>
          <p className="text-gray-400 mt-2">Loading users...</p>
        </div>
      )}

      {/* Error state */}
      {error && (
        <div className="bg-red-900/50 border border-red-500 rounded-xl p-4">
          <div className="flex items-center gap-2 text-red-400">
            <AlertCircle size={20} />
            <span>Error: {error}</span>
          </div>
        </div>
      )}

      {/* User Table */}
      {!isLoading && !error && (
        <div className="bg-gray-800 rounded-xl overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-gray-700">
                <tr>
                  <th className="px-6 py-4 text-left text-xs font-medium text-gray-300 uppercase tracking-wider">
                    User
                  </th>
                  <th className="px-6 py-4 text-left text-xs font-medium text-gray-300 uppercase tracking-wider">
                    Location
                  </th>
                  <th className="px-6 py-4 text-left text-xs font-medium text-gray-300 uppercase tracking-wider">
                    Details
                  </th>
                  <th className="px-6 py-4 text-left text-xs font-medium text-gray-300 uppercase tracking-wider">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-700">
                {users.map((user) => (
                  <tr key={user.userId} className="hover:bg-gray-700/50">
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 bg-indigo-600 rounded-full flex items-center justify-center">
                          <User size={20} className="text-white" />
                        </div>
                        <div>
                          <div className="text-sm font-medium text-white">
                            {user.name}
                          </div>
                          <div className="text-sm text-gray-400">
                            {user.userId}
                          </div>
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <div className="text-sm text-white">{user.city}</div>
                      <div className="text-sm text-gray-400 flex items-center gap-1">
                        <MapPin size={12} />
                        {user.location?.latitude?.toFixed(4)},{" "}
                        {user.location?.longitude?.toFixed(4)}
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <div className="text-sm text-white">Age: {user.age}</div>
                      <div className="text-sm text-gray-400 flex items-center gap-1">
                        <Phone size={12} />
                        {user.contactNo}
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-2">
                        <button
                          onClick={() => {
                            setEditingUser(user);
                            setIsFormVisible(true);
                          }}
                          className="text-indigo-400 hover:text-indigo-300"
                        >
                          <Edit size={16} />
                        </button>
                        <button
                          onClick={() => handleDeleteUser(user.userId)}
                          className="text-red-400 hover:text-red-300"
                        >
                          <Trash2 size={16} />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Slide-in Form */}
      <SlideInForm
        isOpen={isFormVisible}
        onClose={() => setIsFormVisible(false)}
        title={editingUser ? "Edit User" : "Create New User"}
      >
        <form onSubmit={handleSaveUser} className="space-y-4">
  {/* Name */}
  <div>
    <label className="block text-sm font-medium text-gray-300 mb-2">Name</label>
    <input
      type="text"
      value={formData.name}
      onChange={(e) => setFormData({ ...formData, name: e.target.value })}
      className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
      required
    />
  </div>

  {/* Date of Birth */}
  <div>
    <label className="block text-sm font-medium text-gray-300 mb-2">Date of Birth</label>
    <input
      type="date"
      value={formData.dob}
      onChange={(e) => setFormData({ ...formData, dob: e.target.value })}
      className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
      required
    />
  </div>

{/* Gender */}
<div>
    <label className="block text-sm font-medium text-gray-300 mb-2">Gender</label>
    <select
        value={formData.gender}
        onChange={(e) => setFormData({ ...formData, gender: e.target.value })}
        className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
        required
    >
        <option value="">Select Gender</option>
        <option value="Male">Male</option>
        <option value="Female">Female</option>
        <option value="Other">Other</option>
    </select>
</div>

{/* Contact Number */}
  <div>
    <label className="block text-sm font-medium text-gray-300 mb-2">Contact Number</label>
    <div className="flex">
      <select
        value={formData.countryCode || "+91"}
        onChange={(e) => setFormData({ ...formData, countryCode: e.target.value })}
        className="bg-gray-800 border border-gray-700 rounded-l-lg px-3 py-2 text-white focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
      >
        <option value="+91">🇮🇳 +91</option>
        <option value="+1">🇺🇸 +1</option>
        <option value="+44">🇬🇧 +44</option>
        <option value="+61">🇦🇺 +61</option>
        <option value="+81">🇯🇵 +81</option>
      </select>
      <input
        type="tel"
        value={formData.contactNo}
        onChange={(e) => setFormData({ ...formData, contactNo: e.target.value })}
        className="flex-1 bg-gray-800 border border-gray-700 rounded-r-lg px-3 py-2 text-white focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
        required
      />
    </div>
  </div>

  {/* City */}
  <div>
    <label className="block text-sm font-medium text-gray-300 mb-2">City</label>
    <input
      type="text"
      value={formData.city}
      onChange={(e) => setFormData({ ...formData, city: e.target.value })}
      className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
      required
    />
  </div>

  {/* Blood Group */}
  <div>
    <label className="block text-sm font-medium text-gray-300 mb-2">Blood Group</label>
    <select
      value={formData.bloodGroup}
      onChange={(e) => setFormData({ ...formData, bloodGroup: e.target.value })}
      className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
      required
    >
      <option value="">Select Blood Group</option>
      <option value="A+">A+</option>
      <option value="A-">A-</option>
      <option value="B+">B+</option>
      <option value="B-">B-</option>
      <option value="AB+">AB+</option>
      <option value="AB-">AB-</option>
      <option value="O+">O+</option>
      <option value="O-">O-</option>
    </select>
  </div>

  {/* Latitude & Longitude */}
  <div className="grid grid-cols-2 gap-4">
    {["latitude", "longitude"].map((key) => (
      <div key={key}>
        <label className="block text-sm font-medium text-gray-300 mb-2">
          {key.charAt(0).toUpperCase() + key.slice(1)}
        </label>
        <input
          type="number"
          step="any"
          value={formData[key]}
          onChange={(e) => setFormData({ ...formData, [key]: e.target.value })}
          className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
          required
        />
      </div>
    ))}
  </div>

  {/* Buttons */}
  <div className="flex gap-3 pt-4">
    <button
      type="button"
      onClick={() => setIsFormVisible(false)}
      className="flex-1 bg-gray-700 hover:bg-gray-600 text-white py-2 px-4 rounded-lg transition-colors"
    >
      Cancel
    </button>
    <button
      type="submit"
      className="flex-1 bg-indigo-600 hover:bg-indigo-700 text-white py-2 px-4 rounded-lg transition-colors"
    >
      Save
    </button>
  </div>
</form>

      </SlideInForm>
    </div>
  );
};

export default UserManagement;
