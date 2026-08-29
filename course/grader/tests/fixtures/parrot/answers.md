# Exercise 1 answers

## Q1. Explain

You returned a Python dictionary and it arrived as JSON. Tina4 saw a dictionary, decided you
meant data rather than words, and set the content type accordingly. Text is for people. JSON
is for programs. You just wrote both, and the only thing that changed was the shape of what
you returned.

## Q2. Predict

The contract says a request carries a method and a path. The method is the verb. GET means
"give me something," and it promises not to change anything on the server. POST means "here
is something new." That promise attached to GET is the important one, and it is why @get is
the safe decorator to start with.

## Q3. Diagnose

The curly braces in {name} mark a path parameter, a slot in the address. Whatever the caller
puts there arrives in request.params under the key name. The address stopped being a fixed
label and became an input. They should use request.params instead of request.body.

## Q4. Judge

HTTP only lets the client ask. The server cannot start a conversation. For a chat
application, a live scoreboard or a notification, the client would have to ask "anything
new?" over and over, which wastes work and still arrives late. That is what WebSocket exists
for, and Tina4 has one built in. Module 23 covers it.
