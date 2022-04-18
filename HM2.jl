### A Pluto.jl notebook ###
# v0.17.3

using Markdown
using InteractiveUtils

# ╔═╡ 26fd5fb8-4faf-4b14-b16b-29d6042eeae8
using Random, PlutoUI

# ╔═╡ a66ea0f4-64bd-4446-b4f3-cbc5af174610
md"""
## HW1.2 Динамическое программирование для задачи о моторах


>**Задача о моторах** Фирма получила заказ на изготовление моторов различных типов. Мотор типа $i$ может заменить мотор типа $k$, если $i > k$. Производство моторов типа $i$ требует разовых фиксированных затрат на организацию, а также производственных затрат, зависящих от количества производимых моторов. Требуется выполнить заказ с минимальными суммарными затратами.

В этом задании вам необходимо дополнить имеющийся код.
Имеется структура `MPInstance` для хранения входных данных и метод `generateSeminarInstance(.)`, генерирующий входные данные, которые использовались на семинаре.
"""

# ╔═╡ ff445a42-317f-11ec-21bd-4d451327068d
#тут ничего не надо менять
"""
    MPInstance
Структура для хранения входных данных задачи о моторах с полями

`numofmotors` - число типов моторов;

`required` - массив с количеством заказанных моторов каждого из типов;

`fixedcost` - стоимость организации производства моторов каждого из типов;

`productioncost` - стоимость производства одного мотора каждого из типов.
"""
struct MPInstance
	numofmotors::Integer
	required::Vector{Integer} 
	fixedcost::Vector{Integer}
	productioncost::Vector{Integer}
end

# ╔═╡ 99789b87-67e1-4370-9fd0-2e1f60ec9b6c
#тут ничего не надо менять
function generateSeminarInstance()::MPInstance
	numofmotors = 8
	required = [20, 10, 50, 20, 80, 40, 20, 50]
	u = range(1.0, length = numofmotors, step = -0.1)
	fixedcost = 600 .+ 500u
	productioncost = 30u
	return MPInstance(numofmotors, required, fixedcost, productioncost)
end

# ╔═╡ cf57f9ca-a56c-478c-9729-96e4e7c56dd7
#тут ничего не надо менять
"""
    NearestNeighborInstance
Структура для хранения входных данных задачи о ближайшем соседе с полями

`roadlength` - количество мест возможного расположения узлов разбиения;

`servicecost` - массив, содержащий на месте i, j, i <= j стоимость обслуживания отрезка дороги [i, j].
"""
struct NearestNeighborInstance
	roadlength::Integer
	servicecost::Matrix{Integer}
end

# ╔═╡ c15f1a42-9a5f-4bf5-95aa-1a9ee02dbec6
#TODO реализовать функцию, которая по примеру задачи о моторах строит пример задачи о ближайшем соседе
function reduceToNearestNeighbor(mpinstance::MPInstance)::NearestNeighborInstance
	roadlength = mpinstance.numofmotors+1
	servicecost = zeros(Int64, roadlength, roadlength)
	required = mpinstance.required 
	fixedcost = mpinstance.fixedcost 
	productioncost= mpinstance.productioncost 
	#по факту я разбиваю отрезок [1; motors+1], где покрытие [i;j] означает, что мы покрываем все моторы типа i;i+1 ... j+1 и motors+1 нужен для покрытия последнего типа
	for i in 1:roadlength-1
		for j in i+1:roadlength
			sum=0
				for t in i:j-1
					sum+=required[t]
				end
			servicecost[i,j] = fixedcost[i]+productioncost[i]*sum
		end
	end
	return NearestNeighborInstance(roadlength, servicecost)
end

# ╔═╡ cf0722c6-3ba6-4240-97d3-0dc5cf67a8e7
#TODO реализовать функцию решения задачи о ближайшем соседе методом динамического программирования
function solveNearestNeighborWithDP(instance::NearestNeighborInstance)
	servicecost = instance.servicecost
	roadlength=instance.roadlength
	motors = instance.roadlength-1
	objective = 0
	b = ones(Int64, motors)
	#b[i] - покрыли все моторы тип 1, 2, ... i-1. b
	# i = motors
	b[1] = servicecost[1,2]
	for i in 2:motors
		b[i] = servicecost[1, i+1]
		for j in 2:i-1
			b[i] = min(b[i], servicecost[j,i+1] + b[j-1])
		end
	end
	objective = b[motors]
	return objective, b
end

# ╔═╡ 831c4b07-f376-497b-8569-1591e2422a22
#TODO реализуйте функцию, восстанавливающую решение задачи о моторах по решению задачи о ближайшем соседе
function solveMP(instance::MPInstance)
	nninstance = reduceToNearestNeighbor(instance)
	objective, b = solveNearestNeighborWithDP(nninstance)
	with_terminal() do
			print(b)
		end
	servicecost=nninstance.servicecost
	numofmotors = instance.numofmotors
	required = instance.required
	delivered = zeros(Int64, numofmotors)
	k_main = 1
	for k in 1:numofmotors
		if (k==k_main)
			if b[numofmotors+1-k] == servicecost[1,numofmotors+1-k+1]
				for t in 1:numofmotors+1-k
					delivered[1]+=required[t]
				end
				break
			end
			for j in 2:numofmotors-k
				if b[j-1]+ servicecost[j,numofmotors+1-k+1] == b[numofmotors+1-k]
					for t in j:numofmotors+1-k
						delivered[j]+=required[t]
					end
					k_main = numofmotors+1+1-j
					break
				end
			end
		end
	end
	return objective, delivered
end

# ╔═╡ c6852496-8496-4fe2-b7f0-6e964d9888ff
for j in 1:100
	for i in 1:50
		print(j)
		resultstr = "fadsf $j \n"
		if i == 2
			j = 60
			break
		end
		with_terminal() do
			print(resultstr)
		end
	end
end

# ╔═╡ a625574a-0457-49d9-9bc3-f0bcbb1d1865
#тут ничего не надо менять, это вывод на экран целевой функции и решения
function printMPSolution(totalcost::Integer, delivered::Vector{T}) where T <: Integer
	resultstr = "Общая стоимость производства составляет $totalcost\n"
	resultstr *= "Необходимо произвести\n";
	for i in filter(i -> delivered[i] > 0, 1:size(delivered, 1))
		resultstr *= "$(delivered[i]) моторов типа $i\n"
	end
	
	with_terminal() do
		print(resultstr)
	end
end

# ╔═╡ 0e4d9dab-b269-43e2-8eb2-0fe72c64a9c9
#тут посчитается и выведется решение, которое у вас получится
begin
	instance = generateSeminarInstance()
	objective, delivered = solveMP(instance)
	delivered
	printMPSolution(objective, delivered)
end

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
Random = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[compat]
PlutoUI = "~0.7.16"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

[[Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "8d511d5b81240fc8e6802386302675bdf47737b9"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.4"

[[HypertextLiteral]]
git-tree-sha1 = "f6532909bf3d40b308a0f360b6a0e626c0e263a8"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.1"

[[IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "f7be53659ab06ddc986428d3a9dcc95f6fa6705a"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.2"

[[InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "8076680b162ada2a031f707ac7b4953e30667a37"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.2"

[[Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[Parsers]]
deps = ["Dates"]
git-tree-sha1 = "f19e978f81eca5fd7620650d7dbea58f825802ee"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.1.0"

[[PlutoUI]]
deps = ["Base64", "Dates", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "Markdown", "Random", "Reexport", "UUIDs"]
git-tree-sha1 = "4c8a7d080daca18545c56f1cac28710c362478f3"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.16"

[[Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[Random]]
deps = ["Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"

[[Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"
"""

# ╔═╡ Cell order:
# ╟─a66ea0f4-64bd-4446-b4f3-cbc5af174610
# ╠═26fd5fb8-4faf-4b14-b16b-29d6042eeae8
# ╠═ff445a42-317f-11ec-21bd-4d451327068d
# ╠═99789b87-67e1-4370-9fd0-2e1f60ec9b6c
# ╠═cf57f9ca-a56c-478c-9729-96e4e7c56dd7
# ╠═c15f1a42-9a5f-4bf5-95aa-1a9ee02dbec6
# ╠═cf0722c6-3ba6-4240-97d3-0dc5cf67a8e7
# ╠═831c4b07-f376-497b-8569-1591e2422a22
# ╠═c6852496-8496-4fe2-b7f0-6e964d9888ff
# ╠═a625574a-0457-49d9-9bc3-f0bcbb1d1865
# ╠═0e4d9dab-b269-43e2-8eb2-0fe72c64a9c9
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
