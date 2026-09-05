import { useQuery } from '@tanstack/react-query';
import { motion } from 'framer-motion';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card';
import { Avatar } from '@/components/ui/Avatar';
import { Badge } from '@/components/ui/Badge';
import { LoadingSpinner } from '@/components/ui/LoadingSpinner';
import { useAuthStore } from '@/store/auth';
import { api } from '@/services/api';

function Profile() {
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);

  const { data: profileUser, isLoading } = useQuery({
    queryKey: ['user-profile'],
    queryFn: async () => {
      const response = await api.get('/api/v1/users/me');
      return response.data;
    },
    enabled: isAuthenticated,
    staleTime: 1000 * 60 * 5,
  });

  if (!isAuthenticated) {
    return (
      <div className="flex min-h-[60vh] items-center justify-center">
        <Card className="w-full max-w-md">
          <CardHeader>
            <CardTitle className="text-center text-xl">Access Required</CardTitle>
          </CardHeader>
          <CardContent className="text-center">
            <p className="mb-4 text-neutral/70">Please log in to view your profile.</p>
          </CardContent>
        </Card>
      </div>
    );
  }

  if (isLoading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <LoadingSpinner size="lg" />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-base-100 py-8">
      <div className="container mx-auto max-w-4xl px-4">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
        >
          <Card>
            <CardHeader className="flex flex-row items-center gap-4">
              <Avatar
                src={undefined}
                fallback={profileUser?.username}
                size="xl"
              />
              <div>
                <CardTitle className="text-2xl">{profileUser?.username}</CardTitle>
                <div className="mt-1 flex gap-2">
                  <Badge
                    variant={
                      profileUser?.role === 'admin'
                        ? 'error'
                        : profileUser?.role === 'moderator'
                          ? 'warning'
                          : 'info'
                    }
                  >
                    {profileUser?.role}
                  </Badge>
                </div>
              </div>
            </CardHeader>
            <CardContent className="space-y-6">
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <div>
                  <h3 className="text-sm font-medium text-neutral/60">Email</h3>
                  <p className="text-base-content">{profileUser?.email}</p>
                </div>
                <div>
                  <h3 className="text-sm font-medium text-neutral/60">Role</h3>
                  <p className="text-base-content capitalize">{profileUser?.role}</p>
                </div>
                <div>
                  <h3 className="text-sm font-medium text-neutral/60">Member since</h3>
                  <p className="text-base-content">
                    {profileUser?.createdAt
                      ? new Date(profileUser.createdAt).toLocaleDateString()
                      : '-'}
                  </p>
                </div>
                <div>
                  <h3 className="text-sm font-medium text-neutral/60">Last login</h3>
                  <p className="text-base-content">
                    {profileUser?.lastLoginAt
                      ? new Date(profileUser.lastLoginAt).toLocaleDateString()
                      : 'Never'}
                  </p>
                </div>
              </div>
            </CardContent>
          </Card>
        </motion.div>
      </div>
    </div>
  );
}

export default Profile;
