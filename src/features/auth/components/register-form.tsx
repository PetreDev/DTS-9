"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { signUp } from "@/lib/auth/client";
import { registerSchema, type RegisterInput } from "../schemas";
import { trackAuthEvent } from "../actions";
import Link from "next/link";

export function RegisterForm() {
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<RegisterInput>({
    resolver: zodResolver(registerSchema),
  });

  const onSubmit = async (data: RegisterInput) => {
    setIsLoading(true);
    setError(null);

    try {
      const result = await signUp.email({
        name: data.name,
        email: data.email,
        password: data.password,
      });

      if (result.error) {
        setError(result.error.message || "Registration failed");
        return;
      }

      // Track registration event
      await trackAuthEvent("register", data.email);

      router.push("/todos");
      router.refresh();
    } catch {
      setError("Something went wrong");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-5">
      {error && (
        <div className="bg-error-muted border border-error/20 text-error px-4 py-3 rounded-xl text-sm flex items-center gap-2">
          <svg className="w-4 h-4 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          {error}
        </div>
      )}

      <div className="space-y-2">
        <label htmlFor="name" className="block text-sm font-medium text-text-muted">
          Name
        </label>
        <input
          {...register("name")}
          type="text"
          id="name"
          autoComplete="name"
          className="w-full px-4 py-3 bg-bg-input border border-border rounded-xl text-text placeholder:text-text-subtle focus:border-accent focus:ring-1 focus:ring-accent transition-colors"
          placeholder="John Doe"
        />
        {errors.name && (
          <p className="text-error text-sm">{errors.name.message}</p>
        )}
      </div>

      <div className="space-y-2">
        <label htmlFor="email" className="block text-sm font-medium text-text-muted">
          Email
        </label>
        <input
          {...register("email")}
          type="email"
          id="email"
          autoComplete="email"
          className="w-full px-4 py-3 bg-bg-input border border-border rounded-xl text-text placeholder:text-text-subtle focus:border-accent focus:ring-1 focus:ring-accent transition-colors"
          placeholder="you@example.com"
        />
        {errors.email && (
          <p className="text-error text-sm">{errors.email.message}</p>
        )}
      </div>

      <div className="space-y-2">
        <label htmlFor="password" className="block text-sm font-medium text-text-muted">
          Password
        </label>
        <input
          {...register("password")}
          type="password"
          id="password"
          autoComplete="new-password"
          className="w-full px-4 py-3 bg-bg-input border border-border rounded-xl text-text placeholder:text-text-subtle focus:border-accent focus:ring-1 focus:ring-accent transition-colors"
          placeholder="••••••••"
        />
        {errors.password && (
          <p className="text-error text-sm">{errors.password.message}</p>
        )}
        <p className="text-xs text-text-subtle">Must be at least 8 characters</p>
      </div>

      <button
        type="submit"
        disabled={isLoading}
        className="w-full bg-accent text-white py-3 px-4 rounded-xl font-medium hover:bg-accent-hover disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-200"
      >
        {isLoading ? (
          <span className="inline-flex items-center gap-2">
            <svg className="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
            </svg>
            Creating account...
          </span>
        ) : (
          "Create account"
        )}
      </button>

      <p className="text-center text-sm text-text-muted">
        Already have an account?{" "}
        <Link href="/login" className="text-accent hover:text-accent-hover transition-colors">
          Sign in
        </Link>
      </p>
    </form>
  );
}
