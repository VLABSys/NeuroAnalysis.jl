
# function drv(p,n=1,isfreq=false)
#   d=Categorical(p)
#   if n==1
#     return rand(d)
#   end
#   if isfreq
#     pn = round(p[1:end-1]*n)
#     pn = [pn,n-sum(pn)]
#
#     pnc = zeros(Int,length(p))
#     ps = zeros(Int,n)
#     for i in 1:n
#       while true
#         v = rand(d)
#         if pnc[v] < pn[v]
#           pnc[v] += 1
#           ps[i]=v
#           break
#         end
#       end
#     end
#     return ps
#   else
#     rand(d,n)
#   end
# end
#
# function randvec3(xr::Vector,yr::Vector,zr::Vector)
#   dx = Uniform(xr[1],xr[2])
#   dy = Uniform(yr[1],yr[2])
#   dz = Uniform(zr[1],zr[2])
#   Vec3(rand(dx),rand(dy),rand(dz))
# end
# randvec3(;xmin=0,xmax=1,ymin=0,ymax=1,zmin=0,zmax=1)=randvec3([xmin,xmax],[ymin,ymax],[zmin,zmax])
# function randvec3(absmin::Vector)
#   d = Uniform(-1,1)
#   av3 = zeros(3)
#   for i=1:3
#     while true
#       r= rand(d)
#       if abs(r) >= absmin[i]
#         av3[i]=r
#         break;
#       end
#     end
#   end
#   return convert(Vec3,av3)
# end
# randvec3(xabsmin,yabsmin,zabsmin)=randvec3([xabsmin,yabsmin,zabsmin])
# function randvec3(radmin;is2d=false)
#   innerabsmin = radmin*sin(pi/4)
#   absmin = fill(innerabsmin,3)
#   while true
#     cv3 = randvec3(absmin)
#     if is2d;cv3.z=0.0;end
#     if length(cv3) >= radmin
#       return cv3
#     end
#   end
# end

# function convert(::Type{DataFrame},ct::CoefTable)
#    df = convert(DataFrame,ct.mat)
#    names!(df,map(symbol,ct.colnms))
#    [DataFrame(coefname=ct.rownms) df]
#end



# function flcond(fl,fs...)
#   if length(fs)==0
#     fs=collect(keys(fl))
#   end
#   ex = :([{(fs[1],l1)} for l1=fl[fs[1]]][:])
#   for i=2:length(fs)
#     lx=symbol("l$i")
#     push!(ex.args[1].args,:($lx=fl[fs[$i]]))
#     push!(ex.args[1].args[1].args,:((fs[$i],$lx)))
#   end
#   eval(ex)
# end
function flcond(fl,f1)
    conds = [Any[(f1,l1)] for l1 in fl[f1]]
end
function flcond(fl,f1,f2)
    conds = [Any[(f1,l1),(f2,l2)] for l1 in fl[f1],l2 in fl[f2]][:]
end
function flcond(fl,f1,f2,f3)
    conds = [Any[(f1,l1),(f2,l2),(f3,l3)] for l1 in fl[f1],l2 in fl[f2],l3 in fl[f3]][:]
end
function subcond(conds,sc...)
    sci = map(i->issubset(sc,i),conds)
    return conds[sci]
end


function findcond(df::DataFrame,cond)
    i = trues(size(df,1))
    for f in keys(cond)
        i .&= df[f].==cond[f]
    end
    return findall(i)
end
function findcond(df::DataFrame,cond::Vector{Any};roundingdigit=3)
    i = trues(size(df,1))
    condstr = ""
    for fl in cond
        f = fl[1]
        l = fl[2]
        i &= df[Symbol(f)].==l
        if typeof(l)<:Real
            lv=round(l,roundingdigit)
        else
            lv=l
        end
        condstr = "$condstr, $f=$lv"
    end
    return find(i),condstr[3:end]
end
function findcond(df::DataFrame,conds::Vector{Vector{Any}};roundingdigit=3)
    n = length(conds)
    is = Array(Vector{Int},n)
    ss = Array(String,n)
    for i in 1:n
        is[i],ss[i] = findcond(df,conds[i],roundingdigit=roundingdigit)
    end
    vi = map(i->!isempty(i),is)
    return is[vi],ss[vi],conds[vi]
end

"""
Find levels for each factor and indices, repetition for each level
"""
flin(ctc::Dict)=flin(DataFrame(ctc))
function flin(ctc::DataFrame)
    fl=OrderedDict{Symbol,DataFrame}()
    for f in propertynames(ctc)
        fl[f] = condin(ctc[:,[f]])
    end
    return fl
end

"""
In Condition Tests, find each unique condition, number of repeats and its indices
"""
condin(ctc::Dict)=condin(DataFrame(ctc))
condin(ctc::DataFrame) = combine(groupby([ctc DataFrame(i=1:nrow(ctc))], propertynames(ctc), sort = true, skipmissing = true), :i => (x->[copy(x)]) => :i, nrow => :n)

"Get factors of conditions"
condfactor(cond::DataFrame)=setdiff(propertynames(cond),[:n,:i])

"Get `Final` factors of conditions"
function finalfactor(cond::DataFrame)
    fs = String.(condfactor(cond))
    fs = filter(f->endswith(f,"_Final") || ∉("$(f)_Final",fs),fs)
    Symbol.(fs)
end

"Condition in String"
function condstring(cond::DataFrameRow;factor=names(cond))
    join(["$f=$(cond[f])" for f in factor],", ")
end
function condstring(cond::DataFrame;factor=names(cond))
    [condstring(r;factor=factor) for r in eachrow(cond)]
end

"""
Group repeats of Conditions, get `Mean` and `SEM` of responses

rs: responses of each trial
gi: trial indices of repeats for each condition
"""
function condresponse(rs,gi)
    grs = [rs[i] for i in gi]
    DataFrame(m=mean.(grs),se=sem.(grs))
end
function condresponse(rs,cond::DataFrame;u=0,ug="SU")
    crs = [rs[i] for i in cond.i]
    df = [DataFrame(m=mean.(crs),se=sem.(crs),u=fill(u,length(crs)),ug=fill(ug,length(crs))) cond[:,condfactor(cond)]]
end
function condresponse(urs::Dict,cond::DataFrame)
    vcat([condresponse(v,cond,u=k) for (k,v) in urs]...)
end
function condresponse(urs::Dict,ctc::DataFrame,factors)
    vf = filter(f->any(f.==factors),propertynames(ctc))
    isempty(vf) && error("No Valid Factor Found.")
    condresponse(urs,condin(ctc[:,vf]))
end

"Condition Response in Factor Space"
function factorresponse(df;factors = setdiff(propertynames(df),[:m,:se,:u,:ug]),fl = flin(df[:,factors]),fa = OrderedDict(f=>fl[f][f] for f in keys(fl)))
    fm = missings(Float64, map(nrow,values(fl))...)
    fse = deepcopy(fm)
    for i in 1:nrow(df)
        idx = [findfirst(df[i:i,f].==fa[f]) for f in keys(fa)]
        fm[idx...] = df[i,:m]
        fse[idx...] = df[i,:se]
    end
    return fm,fse,fa
end
function factorresponse(unitspike,cond,condon,condoff)
    fms=[];fses=[];factors = condfactor(cond)
    fl = flin(cond[:,factors]);fa = OrderedDict(f=>fl[f][f] for f in keys(fl))
    for u in eachindex(unitspike)
        rs = epochspiketrainresponse_ono(unitspike[u],condon,condoff,israte=true)
        df = condresponse(rs,cond)
        fm,fse,_ = factorresponse(df,factors=factors,fl=fl,fa=fa)
        push!(fms,fm);push!(fses,fse)
    end
    return fms,fses,fa
end

function setfln(fl::Dict,n::Int)
    fln=Dict()
    for f in keys(fl)
        for l in fl[f]
            fln[(f,l)] = n
        end
    end
    return fln
end
function setfln(fl::Dict,fn::Dict)
    fln=Dict()
    for f in keys(fl)
        for i=1:length(fl[f])
            fln[(f,fl[f][i])] = fn[f][i]
        end
    end
    return fln
end

function testfln(fln::Dict,minfln::Dict;showmsg::Bool=true)
    r=true
    for mkey in keys(minfln)
        if haskey(fln,mkey)
            if fln[mkey] < minfln[mkey]
                if showmsg;print("Level $(mkey[2]) of factor \"$(mkey[1])\" repeats $(fln[mkey]) < $(minfln[mkey]).\n");end
                r=false
            end
        else
            if showmsg;print("Level $(mkey[2]) of factor \"$(mkey[1])\" is missing.\n");end
            r=false
        end
    end
    return r
end
function testfln(ds::Vector,minfln::Dict;showmsg::Bool=true)
    vi = find(map(d->begin
    if showmsg;print("Testing factor/level of \"$(d["datafile"])\" ...\n");end
    testfln(d["fln"],minfln,showmsg=showmsg)
end,ds))
end

function condmean(rs,ridx,conds)
    nc = length(conds)
    m = Array(Float64,nc)
    sd = similar(m)
    n = Array(Int,nc)
    for i=1:nc
        r=rs[ridx[i]]
        m[i]=mean(r)
        sd[i]=std(r)
        n[i]=length(r)
    end
    return m,sd,n
end
function condmean(rs,us,ridx,conds)
    msdn = map(i->condmean(i,ridx,conds),rs)
    m= map(i->i[1],msdn)
    sd = map(i->i[2],msdn)
    n=map(i->i[3],msdn)
    return m,hcat(sd...),hcat(n...)
end
