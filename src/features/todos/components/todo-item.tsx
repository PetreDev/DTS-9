"use client";

import { useTransition } from "react";
import { toggleTodoAction, deleteTodoAction } from "../actions";
import type { Todo } from "@/lib/db/schema";

interface TodoItemProps {
  todo: Todo;
}

export function TodoItem({ todo }: TodoItemProps) {
  const [isToggling, startToggle] = useTransition();
  const [isDeleting, startDelete] = useTransition();

  const handleToggle = () => {
    startToggle(async () => {
      await toggleTodoAction({ id: todo.id, completed: !todo.completed });
    });
  };

  const handleDelete = () => {
    startDelete(async () => {
      await deleteTodoAction({ id: todo.id });
    });
  };

  const isPending = isToggling || isDeleting;

  return (
    <div
      className={`group flex items-center gap-4 p-4 bg-bg-card border border-border rounded-xl transition-all duration-200 hover:border-border-hover ${
        isPending ? "opacity-50 pointer-events-none" : ""
      } ${todo.completed ? "opacity-60" : ""}`}
    >
      <button
        onClick={handleToggle}
        disabled={isPending}
        className="shrink-0"
        aria-label={todo.completed ? "Mark as incomplete" : "Mark as complete"}
      >
        <input
          type="checkbox"
          checked={todo.completed}
          onChange={handleToggle}
          disabled={isPending}
          className="pointer-events-none"
          tabIndex={-1}
        />
      </button>

      <span
        className={`flex-1 transition-all duration-200 ${
          todo.completed ? "line-through text-text-muted" : "text-text"
        }`}
      >
        {todo.title}
      </span>

      <button
        onClick={handleDelete}
        disabled={isPending}
        className="shrink-0 p-2 text-text-subtle hover:text-error hover:bg-error/10 rounded-lg opacity-0 group-hover:opacity-100 focus:opacity-100 transition-all duration-200"
        aria-label="Delete todo"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          className="h-4 w-4"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          strokeWidth={2}
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
          />
        </svg>
      </button>
    </div>
  );
}
