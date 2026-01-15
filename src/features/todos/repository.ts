import { db } from "@/lib/db";
import { todo, type Todo, type NewTodo } from "@/lib/db/schema";
import { eq, and } from "drizzle-orm";

export const todoRepository = {
  async findByUserId(userId: string): Promise<Todo[]> {
    return db.query.todo.findMany({
      where: eq(todo.userId, userId),
      orderBy: (todos, { desc }) => [desc(todos.createdAt)],
    });
  },

  async create(data: NewTodo): Promise<Todo> {
    const [created] = await db.insert(todo).values(data).returning();
    return created;
  },

  async updateCompleted(
    id: string,
    userId: string,
    completed: boolean
  ): Promise<Todo | null> {
    const [updated] = await db
      .update(todo)
      .set({ completed, updatedAt: new Date() })
      .where(and(eq(todo.id, id), eq(todo.userId, userId)))
      .returning();
    return updated ?? null;
  },

  async delete(id: string, userId: string): Promise<{ title: string } | null> {
    const [deleted] = await db
      .delete(todo)
      .where(and(eq(todo.id, id), eq(todo.userId, userId)))
      .returning({ title: todo.title });
    return deleted ?? null;
  },
};
