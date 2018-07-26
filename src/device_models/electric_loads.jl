function loadvariables(m::JuMP.Model, devices_netinjection:: A, devices::Array{T,1}, time_periods::Int64) where {A <: PowerExpressionArray, T <: PowerSystems.ElectricLoad}
    on_set = [d.name for d in devices if (d.available == true && !isa(d,PowerSystems.StaticLoad))]

    t = 1:time_periods

    pcl = @variable(m::JuMP.Model, pcl[on_set,t] >= 0.0) # Power output of generators

    varnetinjectiterate!(devices_netinjection,  pcl, t, devices)

    return pcl, devices_netinjection
end

"""
This function adds the power limits of generators when there are no CommitmentVariables
"""
function powerconstraints(m::JuMP.Model, pcl::PowerVariable, devices::Array{T,1}, time_periods::Int64) where T <: PowerSystems.ElectricLoad
    (length(pcl.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent"): true
    # TODO: @constraintref dissapears in JuMP 0.19. A new syntax goes here.
    # JuMP.JuMPArray(Array{ConstraintRef}(JuMP.size(x)), x.indexsets[1], x.indexsets[2])
    @constraintref pmax_cl[1:length(pcl.indexsets[1]),1:length(pcl.indexsets[2])]
    for t in pcl.indexsets[2], (ix, name) in enumerate(pcl.indexsets[1])
        if name == devices[ix].name
            pmax_cl[ix, t] = @constraint(m, pcl[name, t] <= devices[ix].maxrealpower*devices[ix].scalingfactor.values[t])
        else
            error("Bus name in Array and variable do not match")
        end
    end

    JuMP.registercon(m, :loadcontrollimit, pmax_cl)

    return m
end