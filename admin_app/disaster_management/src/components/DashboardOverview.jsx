import React, { useState, useEffect, useCallback, useMemo } from 'react';
import { 
  Menu, X, Home, Map, Users, Shield, UserCheck, Building,
  Bell, User, Search, Plus, Edit, Trash2, MapPin, Phone,
  Calendar, Activity, ChevronRight, AlertCircle, CheckCircle,
  Clock, Settings, LogOut
} from 'lucide-react';


import * as shelterService from '../services/shelterService';
import * as rescuerService from '../services/rescuerService';
import * as rescueOpsService from '../services/rescueOpsService';
import * as userService from '../services/userService';




const DashboardOverview = () => {
  const [stats, setStats] = useState({
    totalUsers: 0,
    totalRescuers: 0,
    totalShelters: 0,
    activeTeams: 0,
    rescuedPeople: 0,
    availableCapacity: 0
  });
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const fetchStats = async () => {
      try {
        const [users, rescuers, shelters, teams] = await Promise.all([
          userService.getUsers(),
          rescuerService.getRescuers(),
          shelterService.getShelters(),
          rescueOpsService.getRescueTeams()
        ]);

        const rescuedPeople = shelters.reduce((sum, s) => sum + (s.rescuedCount || 0), 0);
        const availableCapacity = shelters.reduce((sum, s) => sum + (s.totalCapacity - (s.rescuedCount || 0)), 0);
        const activeTeams = teams.filter(t => t.status === 'On Mission').length;

        setStats({
          totalUsers: users.length,
          totalRescuers: rescuers.length,
          totalShelters: shelters.length,
          activeTeams,
          rescuedPeople,
          availableCapacity
        });
      } catch (err) {
        console.error('Failed to fetch stats:', err);
      } finally {
        setIsLoading(false);
      }
    };

    fetchStats();
  }, []);

  const statCards = [
    { label: 'Total Users', value: stats.totalUsers, icon: Users, color: 'bg-blue-600' },
    { label: 'Total Rescuers', value: stats.totalRescuers, icon: Shield, color: 'bg-red-600' },
    { label: 'Total Shelters', value: stats.totalShelters, icon: Building, color: 'bg-green-600' },
    { label: 'Active Teams', value: stats.activeTeams, icon: UserCheck, color: 'bg-orange-600' },
    { label: 'People Rescued', value: stats.rescuedPeople, icon: CheckCircle, color: 'bg-emerald-600' },
    { label: 'Available Capacity', value: stats.availableCapacity, icon: Activity, color: 'bg-purple-600' }
  ];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-white">Dashboard Overview</h1>
        <p className="text-gray-400 mt-1">Real-time emergency response statistics</p>
      </div>

      {isLoading ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {[...Array(6)].map((_, i) => (
            <div key={i} className="bg-gray-800 rounded-xl p-6 animate-pulse">
              <div className="flex items-center justify-between">
                <div>
                  <div className="h-4 bg-gray-700 rounded w-20 mb-2"></div>
                  <div className="h-8 bg-gray-700 rounded w-12"></div>
                </div>
                <div className="w-12 h-12 bg-gray-700 rounded-full"></div>
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {statCards.map((stat, index) => {
            const Icon = stat.icon;
            return (
              <div key={index} className="bg-gray-800 rounded-xl p-6 hover:bg-gray-750 transition-colors">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-gray-400 text-sm font-medium">{stat.label}</p>
                    <p className="text-2xl font-bold text-white mt-1">{stat.value}</p>
                  </div>
                  <div className={`w-12 h-12 ${stat.color} rounded-full flex items-center justify-center`}>
                    <Icon size={24} className="text-white" />
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Recent Activity */}
      <div className="bg-gray-800 rounded-xl p-6">
        <h2 className="text-xl font-semibold text-white mb-4">Recent Activity</h2>
        <div className="space-y-4">
          <div className="flex items-center gap-3 p-3 bg-gray-700/50 rounded-lg">
            <div className="w-2 h-2 bg-green-500 rounded-full"></div>
            <div className="flex-1">
              <p className="text-white text-sm">Team Alpha dispatched to incident #INC001</p>
              <p className="text-gray-400 text-xs">2 minutes ago</p>
            </div>
          </div>
          <div className="flex items-center gap-3 p-3 bg-gray-700/50 rounded-lg">
            <div className="w-2 h-2 bg-blue-500 rounded-full"></div>
            <div className="flex-1">
              <p className="text-white text-sm">12 people rescued and logged at Central Relief Center</p>
              <p className="text-gray-400 text-xs">5 minutes ago</p>
            </div>
          </div>
          <div className="flex items-center gap-3 p-3 bg-gray-700/50 rounded-lg">
            <div className="w-2 h-2 bg-orange-500 rounded-full"></div>
            <div className="flex-1">
              <p className="text-white text-sm">New rescuer "rescue03" added to the system</p>
              <p className="text-gray-400 text-xs">15 minutes ago</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
export default DashboardOverview;