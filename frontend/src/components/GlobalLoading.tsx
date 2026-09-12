interface GlobalLoadingProps {
  isLoading: boolean
  message?: string
}

export function GlobalLoading({ isLoading, message = 'Loading...' }: GlobalLoadingProps) {
  if (!isLoading) return null

  return (
    <div className="fixed inset-0 bg-gray-900/80 backdrop-blur-sm flex items-center justify-center z-50">
      <div className="text-center">
        <div className="w-12 h-12 border-4 border-blue-400/30 border-t-blue-400 rounded-full animate-spin mx-auto mb-4" />
        <p className="text-white font-medium">{message}</p>
      </div>
    </div>
  )
}
