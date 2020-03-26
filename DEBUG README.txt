Debug mode has, aside from a large mount of prints and screen cluttering arrows, a lot of tools accessed by various keypresses. Pressing one of these accidentally could mean you have to reset your movator system (luckily there's a key for that).

I've divided the function keys into 3 groups for organization:
1. Resetting:
	c - Resets all the self variables, the movator controller's scripts and all other scripts.
	    It'll also drop your actors out of the movator, if after pressing it they don't start moving again
	    paste into the console for a in MovableMan.Actors do a.Lifetime = 0 end

	z - All global movator variables and functions. Press it twice with a short delay between presses to fully reset
	
	If you're running into serious issues, I suggest pressing c then z twice then c again and things should clean up well

2. Display
	v - Displays info on all movators for this controller's team and gives the total number of movators for this team

	b - Displays info on all movator affected actors for this controller's team's movators

	n - Displays info on all the movator paths for this controller's team, also displays how many paths each movator has and the total number of paths

3. Functional
	x - Recalculates all the paths for this controller's team, then places objective arrows above all movators showing their position.
	    Originally had another use that was removed so its display is pretty pointless at the moment.

	m - Toggles mouse cursor, the cursor has two uses:
		1. Left click - Show the start, destination and next movator in a path between two movators.
				Click once near the start movator and then again near the destination movator, click a third time to clear it.
				Note that clicking twice on the same movator may spam errors, requiring you to reset with c.
		2. Middle click - Click near a movator to show its path being generated step by step - see Dijkstra's algorithm in action!

That's all folks!