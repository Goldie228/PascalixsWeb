import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { motion } from 'framer-motion';
import { Button } from '@/components/ui/Button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card';
import { LoadingSpinner } from '@/components/ui/LoadingSpinner';
import { useToast } from '@/components/ui/Toast';
import { api } from '@/services/api';

function Settings() {
  const { success: showSuccess, error: showError } = useToast();
  const queryClient = useQueryClient();
  const [email, setEmail] = useState('');

  const { data: profileUser, isLoading } = useQuery({
    queryKey: ['user-settings'],
    queryFn: async () => {
      const response = await api.get('/api/v1/users/me');
      setEmail(response.data.email || '');
      return response.data;
    },
    staleTime: 1000 * 60 * 5,
  });

  const updateProfile = useMutation({
    mutationFn: async (data: { email: string }) => {
      await api.put('/api/v1/users/me', data);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['user-settings'] });
      showSuccess('Settings saved successfully');
    },
    onError: () => {
      showError('Failed to save settings');
    },
  });

  const handleSave = async () => {
    await updateProfile.mutateAsync({ email });
  };

  if (isLoading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <LoadingSpinner size="lg" />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-base-100 py-8">
      <div className="container mx-auto max-w-2xl px-4">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
        >
          <h1 className="mb-6 text-3xl font-bold text-base-content">Settings</h1>

          <Card>
            <CardHeader>
              <CardTitle className="text-xl">Account Settings</CardTitle>
            </CardHeader>
            <CardContent className="space-y-6">
              <div className="space-y-2">
                <label className="text-sm font-medium text-base-content">Username</label>
                <input
                  type="text"
                  value={profileUser?.username || ''}
                  className="flex h-10 w-full rounded-lg border border-neutral/20 bg-base-200 px-3 py-2 text-sm text-base-content placeholder:text-neutral/50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2 focus-visible:ring-offset-base-100 disabled:cursor-not-allowed disabled:opacity-50 transition-colors"
                  disabled
                />
                <p className="text-xs text-neutral/50">Username cannot be changed</p>
              </div>

              <div className="space-y-2">
                <label className="text-sm font-medium text-base-content">Email</label>
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="flex h-10 w-full rounded-lg border border-neutral/20 bg-base-200 px-3 py-2 text-sm text-base-content placeholder:text-neutral/50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2 focus-visible:ring-offset-base-100 disabled:cursor-not-allowed disabled:opacity-50 transition-colors"
                  placeholder="your@email.com"
                />
              </div>

              <div className="space-y-2">
                <label className="text-sm font-medium text-base-content">Role</label>
                <div className="flex h-10 items-center rounded-lg border border-neutral/20 bg-base-200 px-3 text-sm text-base-content">
                  {profileUser?.role ? (
                    <span className="capitalize">{profileUser.role}</span>
                  ) : (
                    <span className="text-neutral/50">-</span>
                  )}
                </div>
              </div>

              <div className="flex justify-end gap-3">
                <Button
                  variant="outline"
                  onClick={() => setEmail(profileUser?.email || '')}
                >
                  Reset
                </Button>
                <Button onClick={handleSave} disabled={updateProfile.isPending}>
                  {updateProfile.isPending ? (
                    <LoadingSpinner size="sm" />
                  ) : (
                    'Save Changes'
                  )}
                </Button>
              </div>
            </CardContent>
          </Card>

          {/* Danger Zone */}
          <Card className="mt-6 border-error/30">
            <CardHeader>
              <CardTitle className="text-lg text-error">Danger Zone</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="mb-4 text-sm text-neutral/70">
                Once you log out, you will need to sign in again. Your data remains safe.
              </p>
            </CardContent>
          </Card>
        </motion.div>
      </div>
    </div>
  );
}

export default Settings;
