import { motion } from 'framer-motion';
import { Button } from '@/components/ui/Button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card';

function NotFound() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-base-100 px-4">
      <motion.div
        initial={{ opacity: 0, scale: 0.9 }}
        animate={{ opacity: 1, scale: 1 }}
        className="w-full max-w-md"
      >
        <Card>
          <CardHeader>
            <CardTitle className="text-center text-2xl">404 - Page Not Found</CardTitle>
          </CardHeader>
          <CardContent className="text-center">
            <p className="mb-6 text-neutral/70">
              The page you&apos;re looking for doesn&apos;t exist or has been moved.
            </p>
            <div className="flex justify-center gap-3">
              <Button onClick={() => window.location.href = '/'}>Go Home</Button>
              <Button variant="outline" onClick={() => window.location.href = '/dashboard'}>Dashboard</Button>
            </div>
          </CardContent>
        </Card>
      </motion.div>
    </div>
  );
}

export default NotFound;
