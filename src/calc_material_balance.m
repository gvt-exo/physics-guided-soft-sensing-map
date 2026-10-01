function balance = calc_material_balance(P2O5_hat, Rho_acid_hat, Q_H3PO4, Q_NH3, Q_H2O, cfg)
%CALC_MATERIAL_BALANCE Material balance for acid, ammonia, water, and solution density.

    p2o5MassPctHat = P2O5_hat(:);
    rhoPhosphoricAcidHat_g_cm3 = Rho_acid_hat(:);
    h3po4Flow_m3_h = Q_H3PO4(:);
    nh3Flow_kg_h = Q_NH3(:);
    h2oFlow_m3_h = Q_H2O(:);

    h3po4MassFlow100pct_kg_h = rhoPhosphoricAcidHat_g_cm3 .* 1000 .* h3po4Flow_m3_h .* ...
        (p2o5MassPctHat ./ 100) .* 1.38;

    if cfg.use_so3_correction
        h2so4MolarFlow_mol_h = (rhoPhosphoricAcidHat_g_cm3 .* 1000 .* h3po4Flow_m3_h .* ...
            cfg.so3_mass_fraction_in_h3po4 .* cfg.so3_to_h2so4_mass_factor) ./ ...
            cfg.nu_H2SO4;
        nh3FlowForH2SO4_kg_h = 2 .* h2so4MolarFlow_mol_h .* cfg.nu_NH3;
    else
        nh3FlowForH2SO4_kg_h = zeros(size(nh3Flow_kg_h));
    end

    nh3EffectiveFlow_kg_h = nh3Flow_kg_h - nh3FlowForH2SO4_kg_h;
    nh3MassFlow_kg_h = nh3EffectiveFlow_kg_h;
    molarRatioCalc = (nh3MassFlow_kg_h ./ cfg.nu_NH3) ./ ...
        (h3po4MassFlow100pct_kg_h ./ cfg.nu_H3PO4);

    phosphoricAcidSolutionMassFlow_kg_h = rhoPhosphoricAcidHat_g_cm3 .* 1000 .* h3po4Flow_m3_h;
    nh3TotalMassFlow_kg_h = nh3Flow_kg_h;
    waterMassFlow_kg_h = h2oFlow_m3_h .* cfg.rho_H2O;

    phosphoricAcidVolumeFlow_m3_h = h3po4Flow_m3_h;
    nh3VolumeFlow_m3_h = nh3Flow_kg_h ./ cfg.rho_NH3;
    waterVolumeFlow_m3_h = h2oFlow_m3_h;

    rhoSolutionCalc_kg_m3 = (phosphoricAcidSolutionMassFlow_kg_h + nh3TotalMassFlow_kg_h + waterMassFlow_kg_h) ./ ...
        (phosphoricAcidVolumeFlow_m3_h + nh3VolumeFlow_m3_h + waterVolumeFlow_m3_h);
    rhoSolutionCalc_g_cm3 = rhoSolutionCalc_kg_m3 ./ 1000;

    balance = struct();
    balance.m_H3PO4_100 = h3po4MassFlow100pct_kg_h;
    balance.m_NH3 = nh3MassFlow_kg_h;
    balance.Q_NH3_H2SO4 = nh3FlowForH2SO4_kg_h;
    balance.Q_NH3_eff = nh3EffectiveFlow_kg_h;
    balance.Rho_acid_hat = rhoPhosphoricAcidHat_g_cm3;
    balance.Rho_solution_calc = rhoSolutionCalc_g_cm3;
    balance.MO_calc = molarRatioCalc;
end
