'use client';

import React from 'react';

interface InputProps {
  type?: 'text' | 'email' | 'password' | 'number';
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  label?: string;
  error?: string;
  required?: boolean;
  disabled?: boolean;
  className?: string;
  multiline?: boolean;
  rows?: number;
}

export function Input({
  type = 'text',
  value,
  onChange,
  placeholder,
  label,
  error,
  required = false,
  disabled = false,
  className = '',
  multiline = false,
  rows = 4,
}: InputProps) {
  const baseInputClasses = `
    w-full px-4 py-3 rounded-xl text-base
    bg-white border-2 border-[var(--border)]
    placeholder:text-[var(--muted)]
    focus:outline-none focus:border-[var(--primary)] focus:ring-2 focus:ring-[var(--primary)]/20
    disabled:opacity-50 disabled:cursor-not-allowed
    transition-all duration-150
    text-[var(--foreground)]
  `;

  const errorClasses = error ? 'border-[var(--error)] focus:border-[var(--error)] focus:ring-[var(--error)]/20' : '';

  return (
    <div className={`w-full ${className}`}>
      {label && (
        <label className="block text-sm font-medium text-[var(--foreground)] mb-2">
          {label}
          {required && <span className="text-[var(--error)] ml-1">*</span>}
        </label>
      )}
      {multiline ? (
        <textarea
          value={value}
          onChange={(e) => onChange(e.target.value)}
          placeholder={placeholder}
          required={required}
          disabled={disabled}
          rows={rows}
          className={`${baseInputClasses} resize-none ${errorClasses}`}
        />
      ) : (
        <input
          type={type}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          placeholder={placeholder}
          required={required}
          disabled={disabled}
          className={`${baseInputClasses} ${errorClasses}`}
        />
      )}
      {error && (
        <p className="mt-1 text-sm text-[var(--error)]">{error}</p>
      )}
    </div>
  );
}