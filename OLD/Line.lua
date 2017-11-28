function Create(self)
	self.Timer = Timer();
end
function Update(self)
	if self.Timer:IsPastSimMS(300) or self.Age <= 10 then
		for i = 1 , 2 do
			local line2 = CreateMOPixel("Line2" , "Movator.rte");
			line2.Pos = self.Pos
			line2.RotAngle = self.RotAngle*math.rad(90);
			if i == 1 then
				line2.Vel = Vector(self.Vel.Y , self.Vel.X);
			elseif i == 2 then
				line2.Vel = Vector(-self.Vel.Y , -self.Vel.X);
			end
			MovableMan:AddParticle(line2);
		end
		self.Timer:Reset();
	end
		
end