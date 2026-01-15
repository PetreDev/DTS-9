"use server";

import { headers } from "next/headers";
import { revalidatePath } from "next/cache";
import { auth } from "@/lib/auth";
import { trackEvent } from "@/lib/kafka";
import { todoService } from "./service";
import {
  createTodoSchema,
  toggleTodoSchema,
  deleteTodoSchema,
  type CreateTodoInput,
  type ToggleTodoInput,
  type DeleteTodoInput,
} from "./schemas";

type ActionResult<T = unknown> =
  | { success: true; data: T }
  | { success: false; error: string };

async function getAuthenticatedUser() {
  const session = await auth.api.getSession({
    headers: await headers(),
  });

  if (!session?.user) {
    return null;
  }

  return session.user;
}

export async function createTodoAction(
  input: CreateTodoInput
): Promise<ActionResult<{ id: string }>> {
  try {
    const user = await getAuthenticatedUser();
    if (!user) {
      return { success: false, error: "Unauthorized" };
    }

    const result = createTodoSchema.safeParse(input);
    if (!result.success) {
      return { success: false, error: result.error.issues[0]?.message || "Invalid input" };
    }

    const todo = await todoService.create(user.id, result.data.title);
    revalidatePath("/todos");

    // Track todo creation event
    await trackEvent("create", {
      who: user.email,
      what: result.data.title,
    });

    return { success: true, data: { id: todo.id } };
  } catch (error) {
    console.error("Failed to create todo:", error);
    return { success: false, error: "Failed to create todo" };
  }
}

export async function toggleTodoAction(
  input: ToggleTodoInput
): Promise<ActionResult<{ completed: boolean }>> {
  try {
    const user = await getAuthenticatedUser();
    if (!user) {
      return { success: false, error: "Unauthorized" };
    }

    const result = toggleTodoSchema.safeParse(input);
    if (!result.success) {
      return { success: false, error: result.error.issues[0]?.message || "Invalid input" };
    }

    const todo = await todoService.toggle(
      user.id,
      result.data.id,
      result.data.completed
    );

    if (!todo) {
      return { success: false, error: "Todo not found" };
    }

    revalidatePath("/todos");

    // Track todo toggle event
    await trackEvent("complete", {
      who: user.email,
      what: todo.title,
    });

    return { success: true, data: { completed: todo.completed } };
  } catch (error) {
    console.error("Failed to toggle todo:", error);
    return { success: false, error: "Failed to update todo" };
  }
}

export async function deleteTodoAction(
  input: DeleteTodoInput
): Promise<ActionResult<null>> {
  try {
    const user = await getAuthenticatedUser();
    if (!user) {
      return { success: false, error: "Unauthorized" };
    }

    const result = deleteTodoSchema.safeParse(input);
    if (!result.success) {
      return { success: false, error: result.error.issues[0]?.message || "Invalid input" };
    }

    const deleted = await todoService.delete(user.id, result.data.id);

    if (!deleted) {
      return { success: false, error: "Todo not found" };
    }

    revalidatePath("/todos");

    // Track todo deletion event
    await trackEvent("delete", {
      who: user.email,
      what: deleted.title,
    });

    return { success: true, data: null };
  } catch (error) {
    console.error("Failed to delete todo:", error);
    return { success: false, error: "Failed to delete todo" };
  }
}
