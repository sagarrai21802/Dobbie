'use client';

import React from 'react';

interface PrimaryButtonProps {
  text: string;
  onClick: () => void;
  isLoading?: boolean;
  disabled?: boolean;
  type?: 'button' | 'submit';
  className?: string;
}

export function PrimaryButton({ 
  text, 
  onClick, 
  isLoading = false, 
  disabled = false,
  type = 'button',
  className = '' 
}: PrimaryButtonProps) {
  return (
    <button
      type={type}
      onClick={onClick}
      disabled={isLoading || disabled}
      className={`
        w-full h-14 rounded-xl font-semibold text-white text-base
        bg-[var(--primary)] hover:bg-[var(--secondary)] active:bg-[var(--primary)]
        disabled:opacity-50 disabled:cursor-not-allowed
        transition-colors duration-150
        flex items-center justify-center
        ${className}
      `}
    >
      {isLoading ? (
        <span className="flex items-center gap-2">
          <svg className="animate-spin h-5 w-5" viewBox="0 0 24 24">
            <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" fill="none" />
            <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
          </svg>
          Loading...
        </span>
      ) : text}
    </button>
  );
}

interface SecondaryButtonProps {
  text: string;
  onClick: () => void;
  isLoading?: boolean;
  disabled?: boolean;
  className?: string;
}

export function SecondaryButton({ 
  text, 
  onClick, 
  isLoading = false, 
  disabled = false,
  className = '' 
}: SecondaryButtonProps) {
  return (
    <button
      onClick={onClick}
      disabled={isLoading || disabled}
      className={`
        w-full h-14 rounded-xl font-semibold text-[var(--primary)] text-base
        bg-transparent border-2 border-[var(--primary)]
        hover:bg-[var(--primary)] hover:text-white
        disabled:opacity-50 disabled:cursor-not-allowed
        transition-colors duration-150
        flex items-center justify-center
        ${className}
      `}
    >
      {isLoading ? 'Loading...' : text}
    </button>
  );
}

interface TextButtonProps {
  text: string;
  onClick: () => void;
  disabled?: boolean;
  className?: string;
}

export function TextButton({ 
  text, 
  onClick, 
  disabled = false,
  className = '' 
}: TextButtonProps) {
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      className={`
        text-[var(--primary)] font-medium text-sm
        hover:underline
        disabled:opacity-50 disabled:cursor-not-allowed
        ${className}
      `}
    >
      {text}
    </button>
  );
}