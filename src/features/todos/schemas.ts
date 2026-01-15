import { z } from "zod";

export const createTodoSchema = z.object({
  title: z.string().min(1, "Title is required").max(200, "Title too long"),
});

export const toggleTodoSchema = z.object({
  id: z.string().uuid(),
  completed: z.boolean(),
});

export const deleteTodoSchema = z.object({
  id: z.string().uuid(),
});

export type CreateTodoInput = z.infer<typeof createTodoSchema>;
export type ToggleTodoInput = z.infer<typeof toggleTodoSchema>;
export type DeleteTodoInput = z.infer<typeof deleteTodoSchema>;
