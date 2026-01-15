import { headers } from "next/headers";
import { auth } from "@/lib/auth";
import { CreateTodoForm, TodoList } from "@/features/todos/components";
import { SignOutButton } from "./sign-out-button";

export default async function TodosPage() {
  const session = await auth.api.getSession({
    headers: await headers(),
  });

  return (
    <div className="min-h-screen bg-bg">
      {/* Header */}
      <header className="border-b border-border bg-bg-elevated/50 backdrop-blur-sm sticky top-0 z-10">
        <div className="max-w-2xl mx-auto px-4 py-4 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-lg bg-accent/10 flex items-center justify-center">
              <svg
                className="w-4 h-4 text-accent"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                strokeWidth={2}
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4"
                />
              </svg>
            </div>
            <h1 className="text-lg font-semibold">Taskflow</h1>
          </div>
          <div className="flex items-center gap-4">
            <div className="flex items-center gap-2">
              <div className="w-7 h-7 rounded-full bg-accent/20 flex items-center justify-center text-xs font-medium text-accent">
                {session?.user.name?.charAt(0).toUpperCase() || "U"}
              </div>
              <span className="text-sm text-text-muted hidden sm:block">
                {session?.user.email}
              </span>
            </div>
            <SignOutButton />
          </div>
        </div>
      </header>

      {/* Main content */}
      <main className="max-w-2xl mx-auto px-4 py-8 animate-fade-in">
        <div className="mb-8">
          <h2 className="text-2xl font-bold mb-1">My Tasks</h2>
          <p className="text-text-muted">What would you like to accomplish today?</p>
        </div>

        <div className="space-y-6">
          <CreateTodoForm />
          <TodoList />
        </div>
      </main>
    </div>
  );
}
