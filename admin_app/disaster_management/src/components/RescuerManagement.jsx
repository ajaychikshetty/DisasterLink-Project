import React, { useState, useEffect, useCallback } from 'react';
import * as rescuerService from '../services/rescuerService';
import {
  X,
  Plus,
  User,
  MapPin,
  Phone,
  Edit,
  Trash2,
  AlertCircle,
  Mail, // Added for email icon
} from "lucide-react";
import SlideInForm from './SlideInForm';


const RescuerManagement = () => {
  const [rescuers, setRescuers] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);
  const [isFormVisible, setIsFormVisible] = useState(false);
  const [editingRescuer, setEditingRescuer] = useState(null);
  const [formData, setFormData] = useState({
    id: '',
    name: '',
    email: '', // Added email field
    dob: '',
    phones: [''], // first phone shown as primary
    status: 'Free',
    active: true,
    removePassword: false,
  });

  const fetchRescuers = useCallback(async () => {
    try {
      setIsLoading(true);
      setError(null);
      const data = await rescuerService.getRescuers();
      setRescuers(data || []);
    } catch (err) {
      setError(err?.message || String(err));
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchRescuers();
  }, [fetchRescuers]);

  useEffect(() => {
    if (editingRescuer) {
      setFormData({
        id: editingRescuer.id || '',
        name: editingRescuer.name || '',
        email: editingRescuer.email || '', // Populate email for editing
        dob: editingRescuer.dob || '',
        phones: editingRescuer.phone ? [editingRescuer.phone, ...(editingRescuer.extraPhones || [])] : [''],
        status: editingRescuer.status || 'Free',
        active: editingRescuer.active ?? true,
        removePassword: false,
      });
    } else {
      // Reset form for new rescuer, including email
      setFormData({ name: '', email: '', dob: '', phones: [''], status: 'Free', active: true, removePassword: false });
    }
  }, [editingRescuer]);


  const handleSaveRescuer = async (e) => {
    e.preventDefault();
    try {
      setError(null);

      // prepare payload
      const payload = {
        name: formData.name,
        email: formData.email, // Add email to the payload
        dob: formData.dob,
        phone: formData.phones[0] || '',
        extraPhones: formData.phones.slice(1).filter(Boolean),
        status: formData.status,
        active: !!formData.active,
      };

      if (formData.removePassword) payload.removePassword = true;

      if (editingRescuer) {
        await rescuerService.updateRescuer(editingRescuer.id, payload);
      } else {
        await rescuerService.createRescuer(payload); // Pass payload with email
      }

      setIsFormVisible(false);
      setEditingRescuer(null);
      await fetchRescuers();
    } catch (err) {
      setError(err?.message || String(err));
    }
  };

  const handleDeleteRescuer = async (id) => {
    if (!window.confirm('Are you sure you want to delete this rescuer?')) return;
    try {
      setError(null);
      await rescuerService.deleteRescuer(id);
      await fetchRescuers();
    } catch (err) {
      setError(err?.message || String(err));
    }
  };

  return (
    <div className="space-y-6 p-6 min-h-screen">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Rescuer Management</h1>
          <p className="text-gray-400 mt-1">Manage rescue personnel and their availability</p>
        </div>
        <button
          onClick={() => { setEditingRescuer(null); setIsFormVisible(true); }}
          className="flex items-center gap-2 bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2 rounded-lg transition-colors"
        >
          <Plus size={16} />
          Add Rescuer
        </button>
      </div>

      {isLoading && (
        <div className="bg-gray-800 rounded-xl p-8 text-center">
          <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-500"></div>
          <p className="text-gray-400 mt-2">Loading rescuers...</p>
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

      {!isLoading && !error && (
        <div className="bg-gray-800 rounded-xl overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-gray-700">
                <tr>
                  <th className="px-6 py-4 text-left text-xs font-medium text-gray-300 uppercase tracking-wider">Rescuer</th>
                  <th className="px-6 py-4 text-left text-xs font-medium text-gray-300 uppercase tracking-wider">Status</th>
                  <th className="px-6 py-4 text-left text-xs font-medium text-gray-300 uppercase tracking-wider">Team</th>
                  <th className="px-6 py-4 text-left text-xs font-medium text-gray-300 uppercase tracking-wider">Location</th>
                  <th className="px-6 py-4 text-left text-xs font-medium text-gray-300 uppercase tracking-wider">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-700">
                {rescuers.map(rescuer => (
                  <tr key={rescuer.id} className="hover:bg-gray-700/50">
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 bg-red-600 rounded-full flex items-center justify-center">
                          <User size={18} className="text-white" />
                        </div>
                        <div>
                          <div className="text-sm font-medium text-white">{rescuer.name}</div>
                          <div className="text-sm text-gray-400 flex items-center gap-1.5">
                            <Mail size={12} />
                            {rescuer.email || 'No email'}
                          </div>
                        </div>
                      </div>
                    </td>

                    <td className="px-6 py-4">
                      <span className={`px-2 py-1 text-xs font-medium rounded-full ${rescuer.status === 'Free' ? 'bg-green-900 text-green-300' : rescuer.status === 'On Mission' ? 'bg-yellow-900 text-yellow-300' : 'bg-red-900 text-red-300'}`}>
                        {rescuer.status}
                      </span>
                    </td>

                    <td className="px-6 py-4">
                      <div className="text-sm text-white">{rescuer.teamName || 'Unassigned'}</div>
                    </td>

                    <td className="px-6 py-4">
                      <div className="text-sm text-gray-400 flex items-center gap-1">
                        <MapPin size={12} />
                        {rescuer.location ? `${Number(rescuer.location.latitude).toFixed(4)}, ${Number(rescuer.location.longitude).toFixed(4)}` : '—'}
                      </div>
                    </td>

                    <td className="px-6 py-4">
                      <div className="flex items-center gap-2">
                        <button
                          onClick={() => { setEditingRescuer(rescuer); setIsFormVisible(true); }}
                          className="text-indigo-400 hover:text-indigo-300"
                        >
                          <Edit size={16} />
                        </button>
                        <button
                          onClick={() => handleDeleteRescuer(rescuer.id)}
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

      {/* Slide-in form */}
      <SlideInForm isOpen={isFormVisible} onClose={() => setIsFormVisible(false)} title={editingRescuer ? 'Edit Rescuer' : 'Create New Rescuer'}>
        <form onSubmit={handleSaveRescuer} className="space-y-4">
          {/* Full Name */}
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">Full Name</label>
            <input
              type="text"
              value={formData.name}
              onChange={(e) => setFormData(prev => ({ ...prev, name: e.target.value }))}
              className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-indigo-500"
              required
            />
          </div>

          {/* Email Address */}
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">Email Address</label>
            <input
              type="email"
              value={formData.email}
              onChange={(e) => setFormData(prev => ({ ...prev, email: e.target.value }))}
              className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-indigo-500"
              placeholder="user@example.com"
              required
            />
          </div>

          {/* Phone */}
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">Phone Number</label>
            <input
              type="tel"
              value={formData.phones[0]}
              onChange={(e) => setFormData(prev => ({ ...prev, phones: [e.target.value, ...prev.phones.slice(1)] }))}
              className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-indigo-500"
              placeholder="Primary phone number"
              required
            />
          </div>
          {/* Form actions */}
          <div className="flex gap-3 pt-4">
            <button type="button" onClick={() => { setIsFormVisible(false); setEditingRescuer(null); }} className="flex-1 bg-gray-700 hover:bg-gray-600 text-white py-2 px-4 rounded-lg">Cancel</button>
            <button type="submit" className="flex-1 bg-indigo-600 hover:bg-indigo-700 text-white py-2 px-4 rounded-lg">Save</button>
          </div>
        </form>
      </SlideInForm>
    </div>
  );
};

export default RescuerManagement;