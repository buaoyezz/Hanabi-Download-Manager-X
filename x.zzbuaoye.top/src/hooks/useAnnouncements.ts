import { useState, useEffect } from 'react';
import { announcementService } from '../services/announcementService';

export const useAnnouncements = () => {
  const [hasActiveAnnouncements, setHasActiveAnnouncements] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    checkActiveAnnouncements();
  }, []);

  const checkActiveAnnouncements = async () => {
    try {
      setLoading(true);
      const hasActive = await announcementService.hasActiveAnnouncements();
      setHasActiveAnnouncements(hasActive);
    } catch (error) {
      console.error('Failed to check announcements:', error);
      setHasActiveAnnouncements(false);
    } finally {
      setLoading(false);
    }
  };

  return {
    hasActiveAnnouncements,
    loading,
    refresh: checkActiveAnnouncements,
  };
};