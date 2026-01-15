import { todoRepository } from "./repository";
import type { Todo } from "@/lib/db/schema";

export const todoService = {
  async list(userId: string): Promise<Todo[]> {
    return todoRepository.findByUserId(userId);
  },

  async create(userId: string, title: string): Promise<Todo> {
    return todoRepository.create({
      title,
      userId,
    });
  },

  async toggle(
    userId: string,
    id: string,
    completed: boolean
  ): Promise<Todo | null> {
    return todoRepository.updateCompleted(id, userId, completed);
  },

  async delete(userId: string, id: string): Promise<{ title: string } | null> {
    return todoRepository.delete(id, userId);
  },
};
