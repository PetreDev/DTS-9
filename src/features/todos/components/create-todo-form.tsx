"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { useState, useTransition } from "react";
import { createTodoAction } from "../actions";
import { createTodoSchema, type CreateTodoInput } from "../schemas";

export function CreateTodoForm() {
  const [isPending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);

  const {
    register,
    handleSubmit,
    reset,
    formState: { errors },
  } = useForm<CreateTodoInput>({
    resolver: zodResolver(createTodoSchema),
  });

  const onSubmit = (data: CreateTodoInput) => {
    setError(null);
    startTransition(async () => {
      try {
        await createTodoAction(data);
        reset();
      } catch {
        setError("Failed to create todo");
      }
    });
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-2">
      <div className="flex gap-3">
        <div className="flex-1 relative">
          <input
            {...register("title")}
            type="text"
            placeholder="Add a new task..."
            className="w-full px-4 py-3 bg-bg-card border border-border rounded-xl text-text placeholder:text-text-subtle focus:border-accent focus:ring-1 focus:ring-accent transition-colors"
            disabled={isPending}
          />
        </div>
        <button
          type="submit"
          disabled={isPending}
          className="px-5 py-3 bg-accent text-white rounded-xl font-medium hover:bg-accent-hover disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-200 flex items-center gap-2"
        >
          {isPending ? (
            <svg className="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
            </svg>
          ) : (
            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M12 4v16m8-8H4" />
            </svg>
          )}
          <span className="hidden sm:inline">Add</span>
        </button>
      </div>
      {errors.title && (
        <p className="text-error text-sm">{errors.title.message}</p>
      )}
      {error && <p className="text-error text-sm">{error}</p>}
    </form>
  );
}
