import { cn } from '@/lib/utils';

const alertVariants = {
  info: 'border-blue-500/50 text-blue-700 bg-blue-50 dark:bg-blue-950/30 dark:text-blue-300',
  success: 'border-success/50 text-success-content bg-success/10',
  warning: 'border-warning/50 text-warning-content bg-warning/10',
  error: 'border-error/50 text-error-content bg-error/10',
};

interface AlertProps extends React.HTMLAttributes<HTMLDivElement> {
  variant?: 'info' | 'success' | 'warning' | 'error';
}

const Alert = ({ className, variant = 'info', ...props }: AlertProps) => (
  <div
    role="alert"
    className={cn(
      'relative w-full rounded-lg border p-4',
      alertVariants[variant],
      className
    )}
    {...props}
  />
);

const AlertHeader = ({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) => (
  <div className={cn('mb-1 font-medium leading-none', className)} {...props} />
);

const AlertTitle = ({ className, ...props }: React.HTMLAttributes<HTMLHeadingElement>) => (
  <h5 className={cn('mb-1 font-semibold', className)} {...props} />
);

const AlertContent = ({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) => (
  <div className={cn('text-sm opacity-90', className)} {...props} />
);

export { Alert, AlertHeader, AlertTitle, AlertContent };
