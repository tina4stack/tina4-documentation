# Exercise 1 answers

## Q1. Explain

I returned a normal python dict and the browser showed me JSON, so something in the middle
converted it. I dont think I told it to do that anywhere, there is no json flag in my code.
So my guess is the response object checks what type of thing I handed it. If its a dict it
runs it through a json encoder, and if its a string it just sends the string as is.

The content type must get set at the same moment for the same reason. The framework already
decided "this is data" when it saw the dict, so it also knows to say application/json in the
headers instead of text/html. Its one decision, not two.

What I take from this is the shape of what I return IS the instruction. I am not configuring
anything, I am just returning a dict and the framework reads that as meaning data.

## Q2. Predict

I think two things go wrong and only one of them is obvious.

First, when I type a url into the address bar the browser always sends a GET. It has no way
to send a POST from the address bar. So my route is now listening for POST on that path but
nothing is listening for GET anymore, and I should get a 404. Maybe a 405 instead if the
framework is clever enough to notice the path exists but the method is wrong.

Second thing, even if I could somehow send a real POST, I remember reading that tina4 makes
write methods need auth by default and only GET is open. So the POST would come back 401
unless I attached a token or marked it noauth. That one would confuse me for ages because
the route looks completely fine.

## Q3. Diagnose

The bug is they read request.body but the item name is not in the body, its in the path.
Path parameters land in request.params because they came out of the url itself.

The reason it returns null instead of blowing up is the interesting bit. Its a GET request
so there is no body at all. So whatever they pull out of body is nothing. Then they do
MENU.get(item) and .get is the forgiving version of a dict lookup, it hands back None
instead of raising a KeyError. None turns into null when it gets serialised to JSON.

So the failure is quiet. If they had used MENU[item] with square brackets it would have
crashed and they would have found it in a minute. Using .get hid the bug and gave them a
200 response with null in it, which looks like the code ran fine.

## Q4. Judge

No, not on its own, but I would not throw it away either.

The problem is my endpoint can only answer, it cannot start talking. The board would have to
keep asking "has the price changed yet" over and over. Thats polling and its wasteful,
because 99% of the time the answer is no, nothing changed.

But I want to be honest about the scale here. Its one price board in one cafe window. If it
polls every 30 seconds thats 2 requests a minute, which is nothing, and the worst case is a
price is 30 seconds stale on a board nobody is staring at. Adding a websocket means running
a persistent connection, handling reconnects when the cafe wifi drops, and a lot more that
can break in a shop with no technical person in it.

So my actual answer is poll, and be honest that its polling. If this was a stock ticker or
something with real money moving on it I would say websocket, because then being 30 seconds
stale actually costs you. Here it doesnt. I would rather have the boring thing that keeps
working when the wifi wobbles.
