

module dot(
input wire G_lower, G_upper, P_lower, P_upper, 
output wire G_output, P_output
);

//(Gᵢ:ₖ, Pᵢ:ₖ) = (Gᵢ:ⱼ, Pᵢ:ⱼ) ∘ (Gⱼ₋₁:ₖ, Pⱼ₋₁:ₖ)
//Gᵢ:ₖ = Gᵢ:ⱼ + (Pᵢ:ⱼ · Gⱼ₋₁:ₖ)
//Pᵢ:ₖ = Pᵢ:ⱼ · Pⱼ₋₁:ₖ

assign G_output = G_upper | (G_lower & P_upper );
assign P_output = P_upper & P_lower; 


endmodule
