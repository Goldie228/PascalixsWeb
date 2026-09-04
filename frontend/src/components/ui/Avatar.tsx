import { useState } from 'react';
import { cn } from '@/lib/utils';

interface AvatarProps {
  src?: string;
  alt?: string;
  fallback?: string;
  size?: 'sm' | 'md' | 'lg' | 'xl';
  className?: string;
}

export function Avatar({ src, alt, fallback, size = 'md', className }: AvatarProps) {
  const [error, setError] = useState(false);

  const sizes = {
    sm: 'w-8 h-8 text-xs',
    md: 'w-12 h-12 text-sm',
    lg: 'w-16 h-16 text-base',
    xl: 'w-24 h-24 text-lg',
  };

  if (error || !src) {
    return (
      <div
        className={cn(
          'flex items-center justify-center rounded-full bg-primary/20 text-primary font-semibold',
          sizes[size],
          className
        )}
      >
        {fallback?.[0]?.toUpperCase() || alt?.[0]?.toUpperCase() || '?'}
      </div>
    );
  }

  return (
    <img
      src={src}
      alt={alt}
      className={cn('rounded-full object-cover', sizes[size], className)}
      onError={() => setError(true)}
    />
  );
}
