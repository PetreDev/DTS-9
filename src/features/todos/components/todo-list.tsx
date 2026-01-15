import { headers } from "next/headers";
import { auth } from "@/lib/auth";
import { todoService } from "../service";
import { TodoItem } from "./todo-item";

export async function TodoList() {
  const session = await auth.api.getSession({
    headers: await headers(),
  });

  if (!session?.user) {
    return null;
  }

  const todos = await todoService.list(session.user.id);

  if (todos.length === 0) {
    return (
      <div className="text-center py-16">
        <div className="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-bg-card border border-border mb-4">
          <svg
            className="w-8 h-8 text-text-subtle"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            strokeWidth={1.5}
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"
            />
          </svg>
        </div>
        <h3 className="text-lg font-medium mb-1">No tasks yet</h3>
        <p className="text-text-muted text-sm">
          Add your first task above to get started
        </p>
      </div>
    );
  }

  const completedCount = todos.filter((t) => t.completed).length;

  return (
    <div className="space-y-4">
      {/* Progress indicator */}
      <div className="flex items-center justify-between text-sm">
        <span className="text-text-muted">
          {completedCount} of {todos.length} completed
        </span>
        <div className="w-32 h-1.5 bg-bg-card rounded-full overflow-hidden">
          <div
            className="h-full bg-accent rounded-full transition-all duration-500"
            style={{ width: `${(completedCount / todos.length) * 100}%` }}
          />
        </div>
      </div>

      {/* Todo items */}
      <div className="space-y-2 stagger-children">
        {todos.map((todo) => (
          <TodoItem key={todo.id} todo={todo} />
        ))}
      </div>
    </div>
  );
}
