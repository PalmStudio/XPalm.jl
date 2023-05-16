function age_relative_var(age, age_ini, age_fin, val_ini, val_fin)
    if age > age_fin
        return val_fin
    elseif age < age_ini
        return val_ini
    else
        age_relative = age - age_ini
        inc = (val_fin - val_ini) / (age_fin - age_ini)
        return val_ini + age_relative * inc
    end
end