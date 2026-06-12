---
title: "From Ruby to Go: How I Learned to Debug Golang as a Rails Developer"
description: "Switching from Ruby to Go? Here's how to debug Go code using Delve and fmt — plus the mindset shift that made it finally click for a Rails developer."
date: 2025-01-14
last_modified_at: 2025-01-14
author: Nandha Suhendra
categories:
  - General
tags:
  - Debugging
  - Golang
  - Ruby on Rails
  - Neovim
cover_image:
canonical_url:
draft: false
---

As a backend engineer with 5 years of experience in Ruby on Rails, I recently took an opportunity to join a new team in my current company, which has a project to migrate their domain from the big repository into a microservice with Golang. This would be a great opportunity to dive into Golang. The first thing that came to my mind was, “How can I debug Golang code the same way I did in Ruby with my favorite tool, pry ?”. Here’s what I discovered, the challenges I faced, and how I adapted.

Ruby has popular debugging tools like bybug and pry and both of them are easy to use just by calling the method in our code. Then we can call a variable, method, or class, and in pry with can return the block of code where the breakpoint is stopped and detailed of errors is easy to read. However, Go brought its own set of tools and philosophies that I had to learn.

**Challenges I faced:**

1. No Rails-like Error Page

   In Ruby, stack traces are detailed and easy to read where the error is located. But, after I started to code with Go, the error output was minimalistic and I felt cryptic and confused at first.

2. Type Safety

   Coming from a dynamically-type language such as Ruby and Python, developing a project with Go’s strict type often led to compile-time errors that took me a while to understand. However, Go’s linter is powerful and helped me a lot by providing inline error messages in my code editor. I use Neovim :)

3. Concurrency Bugs

   Debugging the async process was intimidating, especially when dealing with race conditions. I was lucky I had experience dealing with it when I was working with Sidekiq in Rails to handle async or background jobs. But still, this problem has its own challenges to solve.

**Tools and Techniques I learned**

1. Using `fmt.Println` or `fmt.Printf("\ndebug: %+v\n\n", variable)`

   As a new person who dives in to Go, `fmt` package is a basic thing I use to debug my code by return anything I want to know such as a variable or result from a function. This package is the same as `puts` or `p` in Ruby.

   ```ruby
   # Ruby
   def add(n, m)
   	puts "N: #{n}\n M:#{m}"
   	n + m
   end

   result = add(1, 3)
   puts result
   ```

   ```go
   // Go
   package main

   import "fmt"

   func add(n, m int) int {
   	fmt.Printf("\nN: %+v\nM: %+v\n\n", n, m)
   	return n + m
   }

   func main() {
   	result := add(1, 4)
   	fmt.Println(result)
   }
   ```

2. The power of `go run` and `go test`

   As long as I use Ruby, the error will return when our program is executing an error code. So, sometimes it makes us confused about when this code will be executed. In Rails, this will immediately appear when we deploy in Production/Staging mode. In Go, I quickly learned to rely on Go’s built-in testing to catch issues early by this command.

3. Debugger tool

   I’m very familiar with bybug and pry to debug my Ruby code instead of using puts. That’s why I felt like using fmt package in Go is easy but it’s not how I work while debugging. After several times I searched on Google about “How to debug in Go”, and I found `dlv` (Delve), Go’s debugger, and it felt like a game-changer. Setting breakpoints and stepping through the code made debugging much more efficient for me.

   ```ruby
   # Ruby
   require "pry"

   def add(n, m)
   	binding.pry
   	n + m
   end

   # terminal: run ruby or rails console
   $: add(5, 10)
   $: (pry) # <- the step will stopped where the `binding.pry` is located
   ```

   ```go
   // Go
   package main

   func add(n, m int) int {
   	return n + m
   }

   func main() {
   	result := add(1, 4)
   	fmt.Println(result)
   }

   // terminal: run delve debug main.go
   (dlv) break main.go:8 // <- will set a breakpoint
   (dlv) continue // <- continue the program, the program will stopped at main.go:8
   ```

I learned that Go’s minimalism isn’t a limitation but a strength. While Ruby emphasizes developer happiness, Go prioritizes simplicity and performance. Each language has its quirks, and learning to debug in Go helped me appreciate its unique approach to problem-solving. I got a few things to learn while using Go that I missed in Ruby.

As a Software Engineer, debugging is a part of our daily activities while developing or fixing issues on our program. Debugging in Go as a Ruby developer was a steep learning curve, but it also broadened my perspective as an engineer.

What was your biggest challenge when learning to Go? Share your tips or experiences in the comments!
