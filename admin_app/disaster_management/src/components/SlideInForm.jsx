import React from "react";
import { X } from "lucide-react";



// Slide-in Form Component
const SlideInForm = ({ isOpen, onClose, title, children }) => {
  return (
    <div
      className={`fixed inset-0 z-50 pointer-events-none`}
      aria-hidden={!isOpen}
      style={{ transition: 'background 0.3s' }}
    >
      {/* Overlay */}
      <div
        className={`absolute inset-0 transition-opacity duration-300 ${isOpen ? 'opacity-100 pointer-events-auto' : 'opacity-0 pointer-events-none'}`}
        onClick={onClose}
      />
      {/* Slide-in panel */}
      <div
        className={`fixed right-0 top-0 h-full w-full max-w-md bg-gray-900 shadow-2xl transition-transform duration-300 ease-in-out pointer-events-auto
          ${isOpen ? 'translate-x-0' : 'translate-x-full'}
        `}
        style={{ willChange: 'transform' }}
      >
        <div className="flex items-center justify-between p-6 border-b border-gray-700">
          <h2 className="text-xl font-semibold text-white">{title}</h2>
          <button onClick={onClose} className="text-gray-400 hover:text-white">
            <X size={24} />
          </button>
        </div>
        <div className="p-6 overflow-y-auto h-full pb-20">
          {children}
        </div>
      </div>
    </div>
  );
};

export default SlideInForm;