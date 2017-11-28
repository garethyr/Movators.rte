function Create(self)
end
function Update(self)
	if self.ToDelete ~= true then
		for node in MovableMan.Particles do
			if node.PresetName == "Movator Zone Node" then
				if node.Pos.X == self.Pos.X and node.Pos.Y == self.Pos.Y then
					node.Lifetime = 1000;
					node.ToDelete = true;
					self.ToDelete = true;
					print ("Node Removed");
				end
			end
		end
	end
	if self.Age > 500 then
		self.ToDelete = true;
	end
end