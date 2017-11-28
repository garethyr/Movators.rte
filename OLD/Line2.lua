function Create(self)
	self.P = false
	self.Lifetime = 151;
end
function Update(self)
	if self.Age >= self.Lifetime -1 and self.P == false then
		local line3 = CreateMOPixel("Line3" , "Movator.rte");
		line3.Pos = self.Pos
		line3.RotAngle = self.RotAngle*math.rad(90);
		line3.Vel = Vector(0,0);
		MovableMan:AddParticle(line3);
		self.P = true;
	end
end