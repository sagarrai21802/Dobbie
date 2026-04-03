'use client';

import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';

interface Theme {
  primary: string;
  secondary: string;
  background: string;
  text: string;
  cta: string;
  error: string;
}

const theme: Theme = {
  primary: '#0891B2',
  secondary: '#06B6D4',
  background: '#ECFEFF',
  text: '#164E63',
  cta: '#059669',
  error: '#DC2626',
};

interface ThemeContextType {
  theme: Theme;
  isLoading: boolean;
}

const ThemeContext = createContext<ThemeContextType>({
  theme,
  isLoading: false,
});

export function useTheme() {
  return useContext(ThemeContext);
}

interface ThemeProviderProps {
  children: ReactNode;
}

export function ThemeProvider({ children }: ThemeProviderProps) {
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    setIsLoading(false);
  }, []);

  return (
    <ThemeContext.Provider value={{ theme, isLoading }}>
      {children}
    </ThemeContext.Provider>
  );
}

export { theme };
export type { Theme };