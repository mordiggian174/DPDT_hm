### A Pluto.jl notebook ###
# v0.17.3

using Markdown
using InteractiveUtils

# ╔═╡ 31d6b4b4-b824-11ec-3aa9-9bf111dc4bdb
begin
	import Pkg
	Pkg.add("JuMP")
	Pkg.add("Cbc")
	Pkg.add("PlutoUI")
	using JuMP, Cbc, Random, PlutoUI
end

# ╔═╡ 669782d9-ac8d-46ef-8627-86aa59f10a15
md"""
# Практические задания 

Оптимизационное моделирование и подход к работе с неопределенностью в оптимизационных моделях, основанный на идее робастности *(основано на иллюстративном примере из учебника A. Ben-Tal, L. El Ghaoui, A. Nemirovski, Robust Optimization / Princeton Series in Applied Mathematics, Princeton Univ. Press, 2009)*.

Для работы следует использовать [Pluto notebook](https://github.com/fonsp/Pluto.jl).

Андрей Мельников, ММФ НГУ, 2022
"""

# ╔═╡ 7ff4142f-88b2-4cfb-8c26-63965370827f
md"""
## Зинченко Сергей, 18121 
"""

# ╔═╡ 5e816ca3-6395-4972-852f-144c294c2fac
md"""
Фабрика производит два наименования лекарств, $D_1$ и $D_2$, содержащих активное вещество $A$, получаемое из сырья двух типов $R_1$ и $R_2$.
Ниже в таблицах приведены параметры производственного процесса:

| Параметр                                | $D_1$ | $D_2$ |
|-----------------------------------------|-------|-------|
| Доход от продажи за 1000 уп.            | 6200  | 6900  |
| Содерж. в-ва $A$ в 1000 уп.             | 0.5   | 0.6   |
| Потребление ручного труда на 1000 уп.   | 90    | 100   |
| Потребление машинного труда на 1000 уп. | 40    | 50    |
| Издержки производства на 1000 уп.       | 700   | 800   |

Характеристики сырья:

| Сырье | Цена за кг. | В-ва $A$ в кг. |
|-------|-------------|----------------|
| $R_1$ | 100         | 0.01           |
| $R_2$ | 199.9       | 0.02           |

Объем имеющихся ресурсов:

| Бюджет | Ручной труд | Машинный труд | Склад сырья |
|--------|-------------|---------------|-------------|
| 100000 | 2000        | 800           | 1000        |
"""

# ╔═╡ da251512-1ccb-4d7f-9cff-35c50a0e5166
md"""
!!! task
**1. (4 балла)**
В ячейке, следующей за ячейкой **Решение**, введите необходимые обозначения и сформулируйте оптимизационную модель выбора объемов производства лекарств, максимизирующих суммарный доход от их продажи.
"""

# ╔═╡ 76758a24-8c66-4e85-80b4-5c31a87b8534
md"""
### Решение
"""

# ╔═╡ 49a2c1d1-b735-4514-ad1a-9d46b2dccf06
md"""
*$\textbf{Множества индексов:}$*

  $\mathcal{I}$ -- индексы лекарств

  $\mathcal{J}$ -- индексы сырья

*$\textbf{Параметры:}$*

  $price_i$ -- доход от продажи за 1000 уп. $i$ лекарства

  $conc_i$ -- концентрация вещества $A$ в 1000 уп. $i$ лекарства $\textbf{a}$

  $hands\_work_i$ -- ручной труд за 1000 уп. $i$ лекарства

  $machine\_work_i$ -- машинный труд за 1000 уп. $i$ лекарства

  $cost_i$ -- издержки за 1000 уп. $i$ лекарства

  $cost_j$ -- цена за 1 кг. (уп.) $j$ сырья

  $A\_substance_j$ -- содержание вещества А в 1 кг. (уп.) $j$ сырья

  $Budget$ - размер бюджета

  $Capacity$ - размер склада в кг.

  $Hands\_work$ - количество доступного ручного труда

  $Machine\_work$ - количество доступного машинного труда
  

*$\textbf{Переменные:}$*

  $r_j \in \mathbb{R}_{\geq 0}$ -- количество купленных кг. $j$ сырья 

  $n_i \in \mathbb{R}_{\geq 0}$ -- количество изготовленных 1000 уп. $i$ лекарства

С использованием введенных обозначений модель максимизации доходов от продажи можно записать следующим образом:

$\sum_{i\in \mathcal{I}} n_i \cdot ( price_i-cost_i)- \sum_{j \in \mathcal{J}} r_j \cdot cost_j \rightarrow \max_{n,r}$

$\sum_{j \in \mathcal{J}} r_j \cdot cost_j +\sum_{i \in \mathcal{I}} n_i \cdot cost_i \leq Budget$ 

$\sum_{i \in \mathcal{I}} n_i \cdot conc_i \leq \sum_{j \in \mathcal{J}} r_j \cdot A\_substance_j$

$\sum_{i \in \mathcal{I}} n_i \cdot hands\_work_i \leq Hands\_work$

$\sum_{i \in \mathcal{I}} n_i \cdot machine\_work_i \leq Machine\_work$

$\sum_{j \in \mathcal{J}} r_j \leq Capacity$

$r_j \in\mathbb{R}_{\geq 0}, \, n_i \in \mathbb{R}_{\geq 0}$.
"""

# ╔═╡ 385939f5-85cb-42a1-b495-748a0d2b131f
md"""
!!! task
**2. (4 балла)**
В ячейке, следующей за ячейкой **Решение**, переведите входные данные задачи в переменные языка Julia и запишите предложенную выше модель максимизации доходов с помощью средств пакета JuMP. О том, как записывать модели с использованием JuMP, можно прочитать [здесь](https://jump.dev/JuMP.jl/stable/manual/variables/).
Ниже можно найти пример того, как это можно сделать. 
"""

# ╔═╡ 96295dce-2b08-4bcd-a16a-4e2edd7db1a1
md"""
### Пример
"""

# ╔═╡ e00c6e06-2df2-4e8d-b8ae-1571b077b3f5
md"""
### Решение
"""

# ╔═╡ 80a6d7f1-457a-436e-aae9-e5d226037dbb
begin
	with_terminal() do 
		m = Model(Cbc.Optimizer)
		set_silent(m)

		@variables(m, 
			begin
				n[1:2]≥0  
				r[1:2]≥0   
				
			end
		)
	
		# выбираем коэффициенты при переменных
		price = [6200, 6900]
		conc = [0.5,0.6]
		hands_work = [90,100]
		machine_work = [40,50]
		cost_n = [700,800]
		cost_r = [100, 199.9]
		a_substance = [0.01, 0.02]
		budget = 100000
		capacity = 1000
		Hands_work = 2000
		Machine_work = 800
	
	
	
		# записываем целевую функцию
		@objective(m, Max, sum(price .* n)-sum(cost_n .* n) - sum(cost_r .* r))
		# однострочное ограничение
		@constraint(m, sum(r .* cost_r) + sum(n .* cost_n) ≤ budget)
		@constraint(m, sum(n .* conc) - sum(r .* a_substance) ≤ 0)
		@constraint(m, sum(n .* hands_work) ≤ Hands_work)
		@constraint(m, sum(n .* machine_work) ≤ Machine_work)
		@constraint(m, sum(r)<= capacity)

		optimize!(m)
	
		# немного усложненный разбор результатов вычислений, учитывающий возможность их окончания с различными статусами 
		if termination_status(m) == OPTIMAL
		    println("Solution is optimal")
		elseif termination_status(m) == TIME_LIMIT && has_values(m)
		    println("Solution is suboptimal due to a time limit, but a primal solution is available")
		else
		    error("The model was not solved correctly.")
		end
		if primal_status(m) == FEASIBLE_POINT
		    println("  drugs: ", value.(n))
			println("  packages: ", value.(r))
			optimal_r = value.(r)
		end
		if dual_status(m) == FEASIBLE_POINT
		    println("  dual solution: c1 = ", dual(c1))
		end
		println("  objective value = ", objective_value(m))
	end
end

# ╔═╡ 2f515149-3693-4432-85c8-3a14109c2afe
md"""
!!! task
В действительности содержание вещества $A$ в сырье может отклоняться от заявленных значений.
Пусть эти отклонения могут составлять до 0.5% для $R_1$ и до 2% для $R_2$ и имеют равномерное распределение.

**3. (2 балла)**
Вычислите значение дохода в худшем случае при использовании решения о закупках сырья, вычисленного в ходе решения задания 2 *(в учебнике утверждают, что должно получиться 6929)*.
"""

# ╔═╡ 71b7cfed-3814-483d-b604-ca37009a4c50
md"""
### Решение
"""

# ╔═╡ 4eca514f-994d-43b4-be9e-cd0e1e0a46df
# Из предыдущей задачи мы знаем, что optimal_r = [0.0, 438.7889425186485]
# 6929 получить никак не удалось. Но все промежуточные значения ~ как в книге:
# 17.552К препарата в предыдущем номере,
# 438.8 кг второго вещества,
# 17.201К препарата тут
begin
	with_terminal() do 
		m = Model(Cbc.Optimizer) 
		set_silent(m) 

		@variables(m, 
			begin
				n[1:2]≥0     
			end
		)
	
		# выбираем коэффициенты при переменных
		price = [6200, 6900]
		conc = [0.5,0.6]
		hands_work = [90,100]
		machine_work = [40,50]
		cost_n = [700,800]
		cost_r = [100, 199.9]
		a_substance = [0.01*0.995, 0.02*0.98]
		budget = 100000
		capacity = 1000
		Hands_work = 2000
		Machine_work = 800
		r = [0.0, 438.788942518648] # Теперь мы точно знаем, сколько будем закупать вещества
		
	
		# записываем целевую функцию
		@objective(m, Max, sum(price .* n)-sum(cost_n .* n) - sum(cost_r .* r))
		# однострочное ограничение
		@constraint(m, sum(r .* cost_r) + sum(n .* cost_n) ≤ budget)
		@constraint(m, sum(n .* conc) - sum(r .* a_substance) ≤ 0)
		@constraint(m, sum(n .* hands_work) ≤ Hands_work)
		@constraint(m, sum(n .* machine_work) ≤ Machine_work)
		@constraint(m, sum(r)<= capacity)

		optimize!(m)
	
		# немного усложненный разбор результатов вычислений, учитывающий возможность их окончания с различными статусами 
		if termination_status(m) == OPTIMAL
		    println("Solution is optimal")
		elseif termination_status(m) == TIME_LIMIT && has_values(m)
		    println("Solution is suboptimal due to a time limit, but a primal solution is available")
		else
		    error("The model was not solved correctly.")
		end

		println("  drugs: ", value.(n))
		println("  packages: ", value.(r))
		optimal_r = value.(r)
		if dual_status(m) == FEASIBLE_POINT
		    println("  dual solution: c1 = ", dual(c1))
		end
		println("  objective value = ", objective_value(m))
		result3 = objective_value(m)
		println("В худшем случае доход равен $result3")		
	end

end

# ╔═╡ 1ce2c046-6efc-43c3-aef7-1ecf7dc25026
md"""
!!! task
**4. (4 балла)**
В условиях задания 3 проведите серии из 1, 10, 100 и 1000 симуляций, сгенерировав случайные реализации неопределенных параметров, вычислите среднее по всем симуляциям серии значение дохода, получаемое при следовании стратегии ``производить $D_1$ с использованием всего доступного количества вещества $A$'' *(в учебнике утверждают, что должно получиться около 7843)*.
"""

# ╔═╡ a46090d0-7704-474c-8148-73921519cb53
md"""
### Решение

Создадим вспомогательную функцию solver, которая будет по реальным значениям концентрации вещества А возвращать значение функции, достигаемое в соответствии со стратегией из задачи 2.
"""

# ╔═╡ 919256a3-663e-4020-a395-1d9ff37b9921
function solver(a_substance)
	m = Model(Cbc.Optimizer) 
	set_silent(m) # отключаем вывод решателя

	@variables(m, 
		begin
			n[1:2]≥0     
		end
	)

	# выбираем коэффициенты при переменных
	price = [6200, 6900]
	conc = [0.5,0.6]
	hands_work = [90,100]
	machine_work = [40,50]
	cost_n = [700,800]
	cost_r = [100, 199.9]
	a_substance = a_substance
	budget = 100000
	capacity = 1000
	Hands_work = 2000
	Machine_work = 800
	r =  [0.0, 438.788942518648]
	

	# записываем целевую функцию
	@objective(m, Max, sum(price .* n)-sum(cost_n .* n) - sum(cost_r .* r))
	# однострочное ограничение
	@constraint(m, sum(r .* cost_r) + sum(n .* cost_n) ≤ budget)
	@constraint(m, sum(n .* conc) - sum(r .* a_substance) ≤ 0)
	@constraint(m, sum(n .* hands_work) ≤ Hands_work)
	@constraint(m, sum(n .* machine_work) ≤ Machine_work)
	@constraint(m, sum(r)<= capacity)

	optimize!(m)


	return objective_value(m)
end

# ╔═╡ ce806054-0c09-48ed-b543-bb50a448873e
begin
	numsim = [1, 10, 100, 1000] # число симуляций в серии
	result4 = zeros(Float64, length(numsim))
	# решение задания 4 тут

	for i in 1:length(numsim)
		for j in 1:numsim[i]
			rand1 = rand(Float64)
			# генерируем минимальные и максимальные отклонения с вероятностями 1/2 
			if rand1>0.5
				delta1 = 0.005
			else
				delta1 = -0.005
			end
			rand2= rand(Float64)
			if rand2>0.5
				delta2 = 0.02
			else
				delta2 = -0.02
			end			
			a_substance = [0.01*(1.0+delta1), 0.02*(1.0+delta2)]
			value = solver(a_substance)
			result4[i]+=value/numsim[i]
		end
	end
	for i in 1:length(numsim)
		println("Средний доход для numsim = $(numsim[i]) равен $(result4[i])\n")
	end
end

# ╔═╡ 32568d25-527d-4b59-883f-c192ba8c066f
md"""
!!! task
**5. (4 балла)**
В условиях задания 3 с использований обозначений, введенных в решении задания 1, запишите робастный аналог модели оптимизации дохода, учитывающей неопределенность процентного содержания вещества $A$ в сырье.
"""

# ╔═╡ 563a99f0-8c20-47c8-b553-010ca668e826
md"""
### Решение
"""

# ╔═╡ 2d859afe-a8c1-449c-ae5d-e9f184aa2bd9
# решение задания 5 здесь
md"""

*$\textbf{Измененения в параметрах}$*

Пусть $real\_A\_substance_j \in [A\_substance_j \cdot (1-\Delta_j) \, ; \, A\_substance_j \cdot (1+\Delta_j)]$

(в нашем случае $\Delta_1 = 0.005$, $\Delta_2 = 0.02$)

*$\textbf{Формулировка}$*

Тогда с использованием введенных обозначений робастный аналог модели максимизации доходов от продажи можно записать следующим образом:

$\sum_{i\in \mathcal{I}} n_i \cdot (price_i - cost_i) - \sum_{j \in \mathcal{J}} r_j \cdot cost_j \rightarrow \min_{n,r}$

$\sum_{j \in \mathcal{J}} r_j \cdot cost_j +\sum_{i \in \mathcal{I}} n_i \cdot cost_i \leq Budget$ 

$\sum_{i \in \mathcal{I}} n_i \cdot conc_i \leq \sum_{j \in \mathcal{J}} r_j \cdot A\_substance_j \cdot (1-\Delta_j)$

$\sum_{i \in \mathcal{I}} n_i \cdot hands\_work_i \leq Hands\_work$

$\sum_{i \in \mathcal{I}} n_i \cdot machine\_work_i \leq Machine\_work$

$\sum_{j \in \mathcal{J}} r_j \leq Capacity$

$r_j \in\mathbb{R}_{\geq 0}, \, n_i \in \mathbb{R}_{\geq 0}$.
"""

# ╔═╡ cfc20f6b-e348-4d2a-ab7e-d7aeb3216668
md"""
!!! task
**6. (6 баллов)**
С помощью пакета JuMP реализуйте сформулированную в рамках решения задания 5 модель и выведите информацию о решении, как это сделано в примере к заданию 2 *(в учебнике утверждают, что значение целевой функции должно с точностью до целых получиться равным 8294)*.
"""

# ╔═╡ 5b1aee41-ef5f-4c4b-a655-13b3dc9b29d9
md"""
### Решение
"""

# ╔═╡ d3c0f820-2bcc-4bc6-bd37-b8438622f26c
begin
	with_terminal() do 
		m = Model(Cbc.Optimizer) 
		set_silent(m) 
		@variables(m, 
			begin
				n[1:2]≥0  
				r[1:2]≥0   
			end
		)
	
		# выбираем коэффициенты при переменных
		price = [6200, 6900]
		conc = [0.5,0.6]
		hands_work = [90,100]
		machine_work = [40,50]
		cost_n = [700,800]
		cost_r = [100, 199.9]
		a_substance = [0.01*0.995, 0.02*0.98] # реализуем худший случай параметров
		budget = 100000
		capacity = 1000
		Hands_work = 2000
		Machine_work = 800
	
	
	
		# записываем целевую функцию
		@objective(m, Max, sum(price .* n)-sum(cost_n .* n) - sum(cost_r .* r))
		# однострочное ограничение
		@constraint(m, sum(r .* cost_r) + sum(n .* cost_n) ≤ budget)
		@constraint(m, sum(n .* conc) - sum(r .* a_substance) ≤ 0)
		@constraint(m, sum(n .* hands_work) ≤ Hands_work)
		@constraint(m, sum(n .* machine_work) ≤ Machine_work)
		@constraint(m, sum(r)<= capacity)

		optimize!(m)
	
		# немного усложненный разбор результатов вычислений, учитывающий возможность их окончания с различными статусами 
		if termination_status(m) == OPTIMAL
		    println("Solution is optimal")
		elseif termination_status(m) == TIME_LIMIT && has_values(m)
		    println("Solution is suboptimal due to a time limit, but a primal solution is available")
		else
		    error("The model was not solved correctly.")
		end
		println("  drugs: ", value.(n))
		println("  packages: ", value.(r))
		if dual_status(m) == FEASIBLE_POINT
		    println("  dual solution: c1 = ", dual(c1))
		end
		println("  objective value = ", objective_value(m))
	end
end

# ╔═╡ Cell order:
# ╟─669782d9-ac8d-46ef-8627-86aa59f10a15
# ╟─7ff4142f-88b2-4cfb-8c26-63965370827f
# ╟─5e816ca3-6395-4972-852f-144c294c2fac
# ╟─da251512-1ccb-4d7f-9cff-35c50a0e5166
# ╟─76758a24-8c66-4e85-80b4-5c31a87b8534
# ╟─49a2c1d1-b735-4514-ad1a-9d46b2dccf06
# ╟─385939f5-85cb-42a1-b495-748a0d2b131f
# ╟─96295dce-2b08-4bcd-a16a-4e2edd7db1a1
# ╟─31d6b4b4-b824-11ec-3aa9-9bf111dc4bdb
# ╟─e00c6e06-2df2-4e8d-b8ae-1571b077b3f5
# ╟─80a6d7f1-457a-436e-aae9-e5d226037dbb
# ╟─2f515149-3693-4432-85c8-3a14109c2afe
# ╟─71b7cfed-3814-483d-b604-ca37009a4c50
# ╟─4eca514f-994d-43b4-be9e-cd0e1e0a46df
# ╟─1ce2c046-6efc-43c3-aef7-1ecf7dc25026
# ╟─a46090d0-7704-474c-8148-73921519cb53
# ╟─919256a3-663e-4020-a395-1d9ff37b9921
# ╟─ce806054-0c09-48ed-b543-bb50a448873e
# ╟─32568d25-527d-4b59-883f-c192ba8c066f
# ╟─563a99f0-8c20-47c8-b553-010ca668e826
# ╟─2d859afe-a8c1-449c-ae5d-e9f184aa2bd9
# ╟─cfc20f6b-e348-4d2a-ab7e-d7aeb3216668
# ╟─5b1aee41-ef5f-4c4b-a655-13b3dc9b29d9
# ╟─d3c0f820-2bcc-4bc6-bd37-b8438622f26c
