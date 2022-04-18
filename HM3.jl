### A Pluto.jl notebook ###
# v0.17.3

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

# ╔═╡ d8e070e6-738f-4f65-a41d-0fdab40892c2
begin
	using Random, Plots, Polynomials, Interpolations, PlutoUI, JuMP, GLPK, Statistics, CSV, Tables, DataFrames, Distances
	md"Загружаем необходимые модули"
end

# ╔═╡ be6956fa-faee-4096-9289-07eae9e88485
md"
*Первая загрузка ноутбука может занять несколько минут. На Windows прерывание ячеек может не работать, поэтому при отладке рекомендуется использовать циклы с небольшим числом итераций. Для запуска ячейки необходимо нажать shift+enter. При этом ячейки, зависящие от запущенной, также будут пересчитаны. Если в ячейке выполняется более одной команды, они должны быть заключены в блок begin-end.* 
"

# ╔═╡ bced3105-2ab1-4b85-906a-c6a4648a2859
md"""
# Задача выбора ассортимента продуктов
Перед открытием магазина его владельцу предстоит определить набор продуктов, которые следует включить в ассортимент. У владельца имеется стартовый бюджет для заключения контрактов на поставку. Заключение контракта происходит по каждому продукту отдельно и связано с известными затратами. 

Имеется информация о спросе на каждый товар: для оценки востребованности товаров проведено маркетинговое исследование, в котором люди сообщали максимальную цену, которую они готовы заплатить за каждый из рассматриваемых к включению в ассортимент товаров. Для упрощения процедуры людям предложили варианты ответа. Таким образом, их ответы не произвольны, а выбираются из списка.

Задача состоит в том, чтобы заключить контракты на поставку продуктов, доход от продажи которых был бы как можно выше.
"""

# ╔═╡ 58742522-4231-48e2-8e94-56895d57ff11
md"
Решение задачи можно построить на основе классической оптимизационной модели -- задачи о рюкзаке, формулируемой следующим образом:
> Имеется рюкзак грузоподъемностью $c$ и набор предметов $I$. Для каждого предмета $i\in I$ заданы его вес $w_i$ и ценность $v_i$. Необходимо найти подмножество предметов суммарным весом не более $c$, имеющих максимальную суммарную ценность.

В данной модели положим грузоподъемность рюкзака равной величине бюджета на заключение контрактов, а в качестве множества предметов возьмем все множество продуктов. Весом предмета будем считать стоимость контракта на поставку соответствующего продукта, а ценностью предмета -- доход от продажи продукта. Решение полученной задачи о рюкзаке можно считать решением исходной задачи: будет выбран набор продуктов, контракты на поставку которых могут быть заключены в рамках имеющегося бюджета, а суммарный доход от продажи продуктов максимален.

Для использования модели нам требуется вычислить величину дохода от продажи каждого из продуктов. Это можно сделать на основе данных маркетингового исследования: оно позволит приближенно восстановить зависимость спроса $d$ от цены $p$. Тогда доход при заданной цене $p$ будет равен $pd(p)$. Выберем цену $p_i$, $i\in I$ для продукта $i$, при которой значение дохода максимально, и возьмем это максимальное значение дохода в качестве ценности соответствующего предмета в задаче о рюкзаке.

В данном ноутбуке вам предложат следующие задания:
* исследовать качество приближения функции спроса в виде $\tilde{d}(p) = e^{- \alpha p}$, где $\alpha > 0$ -- настраиваемый на основе известных данных коэффициент.
* экспериментально сравнить базовый метод отыскания цены, максимизирующей доход, с реализованным вами методом хорд, секущих или касательных.
* разработать приближенный алгоритм для решения задачи о рюкзаке и проанализировать его работу.
* проанализировать влияние параметров алгоритма на его работу и настроить эти параметры.

Общая стоимость заданий -- 34 балла.
"

# ╔═╡ 524f2d22-3c12-11ec-167b-3f9d1bf33745
md"
## Инициализация
"

# ╔═╡ 99167758-610e-4b4c-9004-b45fc04a73d6
begin
	const numofcustomers = 10000
	const numofproducts = 100
	const prices = [0, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000]
	const numofprices = length(prices)
	const budget = 250
	products = []

	const productrandomseed = 1
	const answerspath = "Customers answers.csv"

	md"Инициализируем глобальные переменные"
end

# ╔═╡ 005ccca7-3597-4d5f-99ba-bd76543e8338
md"
## Функция спроса, оптимальные цены и модель ЦЛП
"

# ╔═╡ 6877abb6-9208-4ab5-9c70-464f09f59626
begin
	df = CSV.read(answerspath, DataFrame; header = 1)
	answers = Matrix(df)
	md"Считываем результаты опроса покупателей"
end

# ╔═╡ 8db0ec16-148d-4a46-9b5a-2001aa76571b
df

# ╔═╡ 6373ee2f-8061-40d6-8a47-f42ce011a4b3
begin
	salesbyprice = zeros(Int64, numofproducts, numofprices)
	for i in 1:numofcustomers
		for j in 1:numofproducts
			for p in 1:numofprices
				if answers[i, j] >= prices[p]
					salesbyprice[j, p] += 1
				else
					break
				end
			end
		end
	end
	md"Вычисляем `salesbyprice` -- эмпирическую функцию спроса"
end

# ╔═╡ e81dd923-535e-49a4-a83d-0d015c1eb6fe
begin
	plotly()
	empiricaldemandplot = plot(
		legend = :none,
		xlabel = "price",
		ylabel = "empirical demand")
	for p in 1:numofproducts
		plot!(prices, salesbyprice[p, :])
	end
	empiricaldemandplot
end

# ╔═╡ 8cbf5879-ed95-42fa-90e2-277891bf9ce1
begin
	ipltoshow = 3
	lagrangeipldegree = 2

	md"Эмпирические значения функции спроса нам доступны только в $numofprices точках, однако характер зависимости графики наглядно демонстрируют. Оптимальная цена каждого из продуктов может отличаться от тех, которые были предложены покупателям в опросе. Для выбора оптимальной цены для каждого из продуктов интерполируем таблично заданную функцию спроса -- для этого имеется много возможностей. Сравним интерполяции функции спроса с помощью полиномов Лагранжа и кубических сплайнов. На рисунке ниже изображены графики интерполяционного полинома Лагранжа $lagrangeipldegree степени и интерполяции кубическим сплайном, построенным алгоритмом Fritsch-Carlson [(Википедия)](https://en.wikipedia.org/wiki/Monotone_cubic_interpolation) для продукта Product $ipltoshow. Видим, что полином Лагранжа в нашей ситуации использовать нельзя, а сплайны напротив выглядят вполне естественно.
"
end

# ╔═╡ 9dd296b9-e388-47e5-8ed7-cf3fc349d358
begin
	xs = prices
	ys = salesbyprice[ipltoshow, :]
	l = fit(xs, ys, lagrangeipldegree) # строим интерполяционный полином Лагранжа с помощью функции из пакета Polynomials 
	

	s = interpolate(xs, ys, FritschCarlsonMonotonicInterpolation()) # строим интерполяционный кубический сплайн с помощью пакета Interpolations
	interval = minimum(xs):1.0:maximum(xs)

	plotly()
	scatter(xs, ys, markerstrokewidth=0, label="Data", legend = :bottomleft)
	plot!(l, extrema(xs)..., label="Lagrange")
	plot!(interval, s.(interval), label="Cubic spline")
end

# ╔═╡ 319b8067-fe92-45ef-ad22-20519c12dab9
begin
	demandipl = Vector{Any}(undef, numofproducts)
	for p in 1:numofproducts
		xs = prices
		ys = salesbyprice[p, :]
		demandipl[p] = interpolate(xs, ys, FritschCarlsonMonotonicInterpolation())
	end
		md"Построим интерполяции `demandipl` функции спроса для каждого из продуктов."
end

# ╔═╡ 327ef7b0-3e7f-4983-b92f-00d714ae6f19
begin
	profitfunctoshow = 1
	productslider = @bind profitfunctoshow html"<input type=range min=1 max=numofproducts step=1 value = 1>"
	
	md"""
	Выберите продукт для отображения: $(productslider)
	"""
end

# ╔═╡ 66fafa7a-8323-4ab3-ba4b-0cd72bda1db0
profitfunctoshow

# ╔═╡ d4a1c81c-5bcf-469e-ae55-3e315a0f42a7
begin
	md"На основании приближенной зависимости спроса от цены $\bar{d}(p)$ доход от продажи продукта может быть оценен как $p\cdot \bar{d}(p)$. Построим график этой функции для продукта $profitfunctoshow и сравним с реальным графиком функции дохода ``pd(p)`` (которую мы не знаем на самом деле)."
end

# ╔═╡ acc58a0f-de23-4e2d-a812-50048031280e
begin
	profitipl(x) = x * demandipl[profitfunctoshow](x)
	profitplot = plot(
		profitipl, 
		extrema(prices)..., 
		label = "Interpolated profit function",
		xlabel = "price",
		ylabel = "profit"
	)
	
	profitreal(x) = x * products[profitfunctoshow].demand(x) * numofcustomers
	plot!(profitreal, extrema(prices)..., label = "Real profit function")
end

# ╔═╡ f07800e0-7272-47c6-97b4-481f8c7c86f8
md"""
Из-за того, что наши данные не отображают снижения спроса до нуля при неограниченном росте цены, для приближений рост дохода после первого пика продолжается линейной зависимостью. Это объясняется тем, что среди предложенных в опросе цен не было цен достаточно больших для того, чтобы все покупатели отказались от покупки, и мы наблюдаем постоянное количество покупателей, согласных купить товар и за 2000, и за 5000. Таким образом, для больших $p$ интерполяции $\bar{d}(p)$ становятся константами, а функции дохода $p\bar{d}(p)$ демонстрируют линейный рост.
"""

# ╔═╡ 00777e04-787e-47ef-b97f-fa6edf7f4489
md"Заметим, что в целом, для небольших значений цены приближение функции спроса кубическим сплайном позволяет достаточно аккуратно приближать функцию дохода, но наших данных недостаточно, чтобы адекватно оценивать спрос при больших значениях цены -- там настоящая функция и приближение значительно расходятся.

Тем не менее в нашем случае близкую к оптимальной цену можно отыскать, решив уравнение $(p\bar{d}(p))' = 0$. Рассмотрим график функции $(p\bar{d}(p))'$ для продукта $profitfunctoshow."

# ╔═╡ aaf6e457-ef22-4646-8369-a23a450b697d
md"Теперь у нас есть оценки размеров дохода от продажи каждого из продуктов, и мы готовы к формулировке оптимизационной модели по выбору ассортимента продуктов. Ее можно решить с помощью ЦЛП-решателя, мы будем пользоваться одним из бесплатных решателей -- GLPK. Найденный решателем набор продуктов является оптимальным. Вот информация о нем:"

# ╔═╡ 1e8dc2cc-e33b-448b-bd3d-3c7b374c2ff5
md"""
## Алгоритм локального поиска
"""

# ╔═╡ 5d24bc1c-42d5-4d97-91d4-608c951afe48
md"""
В качестве базового алгоритма рассмотрим рандомизированный локальный поиск, просматривающий решения задачи о рюкзаке, закодированные (0, 1)--векторами длины `numofproducts`, компоненты которых принимают значение 1, если соответствующий предмет помещается в рюкзак и 0 в противном случае.
Алгоритм использует два типа модификаций решения: *flip*, меняющий значение одной из компонент решения, и *swap*, меняющий некоторую единицу и некоторый ноль местами. 
Схема базового алгоритма следующая

1. Построить начальное решение `initsol`
2. Положить `cursol` = `initsol` и `record` = `initsol`
3. Повторять до срабатывания критерия остановки 
   
   1. Построить `numofflips` решений с помощью случайной модификации flip, выбрать 
      из них лучшее `bestflip` и положить `cursol` = `bestflip`, обновить `record`, 
      если требуется
   2. Если переход к `bestflip` улучшил `cursol`, на новый виток цикла
   3. Иначе построить `numofswaps` решений с помощью случайной модификации swap, 
      выбрать из них лучшее `bestswap` и положить `cursol` = `bestswap`, обновить 
      `record`, если требуется

4. Вернуть `record`

"""

# ╔═╡ 74403e12-59b1-41c2-9b00-a5a377f1619b
md"
Проследим за работой алгоритма, изучив графики изменения целевой функции решения `cursol` и расстояния между решениями `cursol` и `record`. График изменения целевой функции показывает, что алгоритм двигается направленно и на фазе наполнения рюкзака быстро улучшает ее. После наполнения рюкзака добавлять предметы больше нельзя, и требуются замены одних предметов на другие. При таких изменениях значение целевой функции может ухудшаться, однако на графике видно, что алгоритм сменил область поиска, преодолев регион с менее качественными решениями, и обнаружил два новых более привлекательных решения. 

На графике расстояний между `cursol` и `record` мы убеждаемся, что алгоритм не зацикливается на просмотре соседних с `record` решений. Таким образом, мы можем диагностировать, что алгоритм имеет достаточную способность к диверсификации поиска. При этом, если нас не устраивает найденное значение целевой функции 8.96e6 (напомним, оптимум из решения ЦЛП равен 9.13e6), выглядит оправданным проведение экспериментов по расширению арсенала интенсификационных инструментов -- перезапуск с лучшего найденного, модификация параметров `numofflips` и `numofswaps` в сторону увеличения. Возможно, более аккуратная настройка этих параметров либо увеличение вычислительного бюджета алгоритма.
"

# ╔═╡ 1882c948-35c0-4bdb-a846-fbc997f48628
md"
Поскольку реализованный алгоритм является вероятностным, отдельное внимание следует уделить устойчивости его работы -- насколько высок разброс возвращаемых алгоритмом значений целевой функции. Проведем 100 запусков и проследим за средним значением целевой функции и ее стандартным отклонением. Видим, что погрешность имеет порядок $10^5$, что при значениях целевой функции порядка $10^7$ составляет единицы процентов.
"

# ╔═╡ e786cfd6-f834-44bc-be87-285e1bb95402
md"
!!! task
**TODO: выполнить задания**

1 (5 балла). Добавить к базовому алгоритму локального поиска процедуру порождения стартового решения с помощью жадного алгоритма. Сравнить эффективность алгоритма без предложенной процедуры и с ней.

2 (10 баллов). Реализовать алгоритм наискорейшего подъема: на каждой итерации просматривать все решения в окрестности flip и swap и выбирать лучшее из них. Если выбранное решение хуже текущего, алгоритм останавливается.

3 (10 баллов). Реализовать GRASP (greedy randomized adaptive search procedure) для инициализации алгоритма наискорейшего подъема. GRASP строит решение по шагам, как и стандартный жадный алгоритм. На каждом шаге случайным образом выбирается $k$ предметов, которых нет в рюкзаке, из них выбирается лучший и добавляется в рюкзак. Шаг повторяется до тех пор, пока добавление текущего выбранного предмета не нарушает ограничений на вместимость рюкзака. Построенное таким образом решение выбрать в качестве стартового для алгоритма наискорейшего подъема. Реализовать процедуру мультистарта, в которой алгоритм наискорейшего подъема многократно перезапускается, стартуя с решений, порождаемых с помощью GRASP. Сравнить такую схему с базовым алгоритмом локального поиска.
"

# ╔═╡ d5951cfe-f237-4589-89bf-561d72ebf2d8
md"
!!! solution

**Задача №1**

Добавить к базовому алгоритму локального поиска процедуру порождения стартового решения с помощью жадного алгоритма. Сравнить эффективность алгоритма без предложенной процедуры и с ней.
"

# ╔═╡ 6d0a13a7-ad46-4f20-81da-a104ba6bb7da
md"
**Тестируем**
"

# ╔═╡ f5152b0f-ae56-4a42-9fe2-2e9c0793880a
md"
Результаты нескольких запусков
"

# ╔═╡ 07173e53-b4ed-4623-be47-19d9acaa4384
md"
Видим, что результат стал хуже. Дисперсия стала выше.

Также на графике видно, что начальная инициализация достаточно хорошая. Значение целевой функции на ней улучшается несущественно в ходе работы алгоритма.
"

# ╔═╡ 7c7e78db-5809-41f2-9a52-77c01e3a1de3
md"
**Задача №2**

Реализовать алгоритм наискорейшего подъема: на каждой итерации просматривать все решения в окрестности flip и swap и выбирать лучшее из них. Если выбранное решение хуже текущего, алгоритм останавливается.
"

# ╔═╡ 4c15422e-4158-4b5b-b2ac-db95ea61252e
md"
**Тестируем**
"


# ╔═╡ d83f7e93-b0ab-41d7-afc6-467dbf12ce84
md"
**Итоги**

Алгоритм детерминирован и дисперсии никакой нет, что ожидаемо.
Также понятно по логике алгоритма, что результат работы на нулевой инициализации совпадет с версией жадного алгоритма без плотностей.
А когда на промежуточном этапе решение совпадет с решением жадного алгоритма, он остановится. Ведь ни один из 1-соседей не может улучшить целевую функцию.

В этом можно так же убедиться, если запустить алгоритм на greedyInitialSolution, тогда ни одного рекорда не появится. Алгоритм закончит работу за одну итерацию цикла while

Если же запускать на решениях, порождаемых grasp'ом, то алгоритм, просматривающий все окрестности, будет дает лучший результат.
"

# ╔═╡ 06bf0f8e-696d-47f2-aced-4a0d1d9b5e94
md"
**Задача №3**

Реализовать GRASP (greedy randomized adaptive search procedure) для инициализации алгоритма наискорейшего подъема. GRASP строит решение по шагам, как и стандартный жадный алгоритм. На каждом шаге случайным образом выбирается k предметов, которых нет в рюкзаке, из них выбирается лучший и добавляется в рюкзак. Шаг повторяется до тех пор, пока добавление текущего выбранного предмета не нарушает ограничений на вместимость рюкзака. Построенное таким образом решение выбрать в качестве стартового для алгоритма наискорейшего подъема. Реализовать процедуру мультистарта, в которой алгоритм наискорейшего подъема многократно перезапускается, стартуя с решений, порождаемых с помощью GRASP. Сравнить такую схему с базовым алгоритмом локального поиска.
"

# ╔═╡ 71f92a0f-f5f0-4950-adec-188a3d9bf18d
md"
График для мультистарта тоже можно привести, но такого задания нет, а просто так возиться с общими номерами итерациями я не хочу :(
"

# ╔═╡ 1a713838-7cb6-4ef1-be4e-5bb7d5733918
md"
**Насчет seed'ов** 

Для каждого запуска будет выбран сид, равный номеру запуска.
В соответствии с ним будет выбираться на различных стартах случайным образом сид для процедуры алгоритма наискорейшего подъема. 
"

# ╔═╡ 4b74bc7c-55b9-4608-a5ca-581c1395e6cc
md"
**Насчет результатов**

С ростом numofstarts значение рекорда растет, дисперсия падает, что ожидаемо.

А вот с ростом k результат ведет себя непредсказуемо. Иногда даже случается так, что дисперсии от запусков нет (k=41,numofstarts=4 std = 0, k = 40, numofstarts = 4 std = 6664)

Иногда смена параметра k вообще ничего не меняет - (63,4) (64,4)

При некоторых значениях находится сразу оптимальное решение (65,4), например.

Думаю, многое зависит от того, какой сид мы выбираем при повторении запусков. Скорее всего, при конкретных сидах алгоритму везет и он выбирает удачно подвыборку для жадного алгоритма.
"

# ╔═╡ d251bc5a-3ab8-48ff-9795-f51d024f69fe
md"""
## Вспомогательный код
"""

# ╔═╡ ab70c5d2-1c09-4ea7-9635-90955b99e475
@doc raw"
Stores product attributes. Contains the fields:

`lambda` -- demand function parameter;

`demand` -- demand function ``e^{-\lambda p}`` where ``p`` is a product's price;

`contractprice` -- price of a contract to sell the product.
"
Base.@kwdef struct Product
	lambda::AbstractFloat
	demand::Function = x -> exp(-lambda*x) 
	contractprice::Integer
end

# ╔═╡ b7cac7c2-0e4c-44a1-80e3-850ffae32b84
"""
	generateProducts(numofproducts::Integer, seed::Integer)::Vector{Product}
Generates a list of products with randomly chosen parameters.
# Arguments
`numofproducts` -- number of products;

`seed` -- pseudorandom sequence seed.
"""
function generateProducts(numofproducts::Integer, seed::Integer)::Vector{Product}
	Random.seed!(seed)

	for i in 1:numofproducts
		lambda = rand(0.001:0.0001:0.1)
		contractprice = rand(5:25)
		push!(products, Product(lambda = lambda, contractprice = contractprice))
	end
	return products
end

# ╔═╡ 1cf96b28-f109-4e8f-93b6-c35183024025
@doc """
	generateAnswers(numofcustomers::Int64, numofproducts::Int64)
Generates the file `Customers answers.csv` in the directory where the present notebook is located.
# Arguments
`numofcustomers` -- number of customers;

`numofproducts` -- number of products.
"""
function generateAnswers(numofcustomers::Int64, numofproducts::Int64)
	answers = zeros(Int64, numofcustomers, numofproducts)
	products = generateProducts(numofproducts, 0)
	numofprices = size(prices, 1)

	for i in 1:numofcustomers
		for j in 1:numofproducts
			point = rand(0:0.001:1)
			price = first(prices)
			
			for p in 1:numofprices
				if point < products[j].demand(prices[p])
					price = prices[p]
				else
					break
				end
			end
			answers[i, j] = price
		end
	end
	header = []
	for i in 1:numofproducts
		push!(header, "Product $i")
	end
	data = Tables.table(answers)
	CSV.write(answerspath, data, header = header)
end

# ╔═╡ b2def32b-2660-4d3b-ae85-b8213c2802b5
begin
	generateProducts(numofproducts, productrandomseed)
	generateAnswers(numofcustomers, numofproducts)
	md"Генерируем начальные данные"
end

# ╔═╡ 2675334e-9b82-47a9-84a0-4cfc134f687c
@doc raw"

Stores a data of the integer bin packing problem. Contains the fields:

`capacity` -- knapsack capacity;

`numofitems` -- number of item types;

`weight` -- items' weights;

`value` -- items' values;

`amount` -- number of items of a specific type.
"
struct KnapsackInstance
	capacity::Integer
	numofitems::Integer
	weight::Vector{Integer}
	value::Vector{Integer}
	amount::Vector{Integer}
end

# ╔═╡ f7517994-e184-4d72-a4be-7290fe71b652
@doc md"
	generateKnapsackInstance(numofitems::Integer, seed::Integer = 
	0, capacity::Integer = 100)::KnapsackInstance
Generates an instance of the binary knapsack problem with random data.
# Arguments
`numofitems` -- number of items;

`seed` -- the seed value of the pseudorandom sequence;

`capacity` -- the knapsack capacity.
"
function generateKnapsackInstance(numofitems::Integer, seed::Integer = 
	0, capacity::Integer = 100)::KnapsackInstance
		Random.seed!(seed)
		weight = rand(10:40, numofitems)
		value = rand(5:25, numofitems)
		amount = ones(Int64, numofitems)
		return KnapsackInstance(capacity, numofitems, weight, value, amount)    
end

# ╔═╡ 444879c7-75fe-49c5-bfa7-c04b46fc9130
@doc md"
	solveKPwithMIP(knapsackInstance::KnapsackInstance, verbose = true)
Solves the knapsack problem instance with GLPK solver.
# Arguments
`knapsackInstance` -- instance data;

`verbose` -- indicator if the solution must be printed out or not.
"
function solveKPwithMIP(knapsackInstance::KnapsackInstance, verbose = true)
    model = Model(GLPK.Optimizer)
    @variable(model, x[i = 1:knapsackInstance.numofitems] <= knapsackInstance.amount[i], integer = true, lower_bound = 0)
    # Objective: maximize profit
    @objective(model, Max, knapsackInstance.value' * x) 
    # Constraint: fit the knapsack capacity
    @constraint(model, knapsackInstance.weight' * x <= knapsackInstance.capacity)
    # Solve problem using MIP solver
    optimize!(model)
    if verbose
	    println("Objective is: ", objective_value(model))
	    println("Solution is to take products:")
	    for i in 1:knapsackInstance.numofitems
			if value(x[i]) > 0.5
	            print("$i, ")
			end
		end
    end
#    Test.@test termination_status(model) == MOI.OPTIMAL
#    Test.@test primal_status(model) == MOI.FEASIBLE_POINT
#    Test.@test objective_value(model) == 16.0
    return
end


# ╔═╡ ab9d57d9-7662-46da-b6e8-256a82a119c0
@doc md"
	profitGradient(demandinterpolation::Interpolations.MonotonicInterpolation, x::Real)
Computes the value of the profit derivative.
# Arguments
`demandinterpolation` -- cubic spline interpolating the demand function;

`price` -- the point to compute the derivative in.
"
function profitGradient(demandinterpolation::Interpolations.MonotonicInterpolation, price::Real)
	return Interpolations.gradient(demandinterpolation, price)[1] * price + demandinterpolation(price)
end
	

# ╔═╡ 5a3fc936-5fd9-4ec7-a14b-1da1bcfb1a2c
plot(interval, [profitGradient(s, t) for t in interval], label = "Profit gradient")

# ╔═╡ 958e9699-6d91-4d78-b1cd-9b25774327ae
@doc md"
	localizeZero(f::Function, leftbound::Real, rightbound::Real, eps::Real, N::Integer = 100)
Finds the interval where the root of the equation $f(x) = 0$ is located.
# Arguments
`f` -- the fuction in the lhs of the equation;

`leftbound` -- the initial value of the left bound of the interval;

`rightbound` -- the initial value of the right bound of the interval;

`eps` -- desired size of the final interval;

`N` -- the maximal number of dichotomy iterations.
"
function localizeZero(f::Function, leftbound::Real, rightbound::Real, eps::Real, N::Integer = 100)
	a = leftbound
	b = rightbound
	h = b - a
	counter = 0
	while b - a > eps && counter < N
		h /= 2
		prev = a
		next = a + h
		while next + min(1e-6, eps) < b
			if f(prev) >= 0 && f(next) <= 0
				a = prev
				b = next
				break
			end
			prev = next
			next += h
		end
	end
	return a, b
end

# ╔═╡ a86da162-959c-4b98-bed1-6f7571ad5403
begin
	optimalprice = zeros(Int64, numofproducts)
	
	for p in 1:numofproducts
		left = extrema(prices)[1]
		right = extrema(prices)[2]
		eps = 0.5
		priceLb, priceUb = localizeZero(x -> profitGradient(demandipl[p], x), left, right, eps)
		candidates = [
			ceil(priceLb),
			floor(priceUb)]
		optimalprice[p] = candidates[argmax(demandipl[p].(candidates))]
	end
	md"Вычислим оптимальные цены `optimalprice` для продуктов, решив указанное выше уравнение, например, методом дихотомии. Отметим на графике найденную точку и убедимся в том, что соответствующая цена близка к оптимальной для продукта $profitfunctoshow."
end

# ╔═╡ ac69db64-0de4-49d4-8899-2b207d8a1316
begin
	plot(profitplot)
	scatter!([optimalprice[profitfunctoshow]], [profitipl(optimalprice[profitfunctoshow])], markerstrokewidth=0, label = "Chosen price")
end

# ╔═╡ 276f0663-a7ac-422f-92e8-8280868135e4
begin
	profit = zeros(Int64, numofproducts)
	cost = zeros(Int64, numofproducts)
	amount = ones(Int64, numofproducts)

	for p in 1:numofproducts
		profit[p] = ceil(Int64, optimalprice[p] * demandipl[p](optimalprice[p]))
		cost[p] = products[p].contractprice
	end
	instance = KnapsackInstance(budget, numofproducts, cost, profit, amount)
	
	with_terminal() do
		solveKPwithMIP(instance)
	end
end

# ╔═╡ b911a44b-dbb2-4ff1-94cf-0a28b1bc8478
@doc raw"
Stores the parameters of the local solver and its global variables. Contains the fields:

* input data:

`instance` -- knapsack problem instance;

* search parameters:

`penaltyfactor` -- penalty for capacity constraint violation;

`inftolerance` -- tolerance for capacity constraint violation;

`numofflips` -- number of random flip neighbors considered during the iteration;

`numofswaps` -- number of random swap neighbors considered during the iteration;

`randomseed` -- seed of pseudorandom sequence;

* termination criteria:

`numofiters` -- maximal number of iterations;

`functionevaluations` -- maximal number of function evaluation;

* computations workflow information:

`objectivegraph` -- the sequence of the objective function values for the current solution;

`infeasibilitygraph` -- the sequence of the infeasibility values for the current solution;

`recordupdates` -- tuples (obj, iter) where obj is the record's objective function value and iter is the iteration number when the record was obtained;

`distancetorecordgraph` -- the sequece of Hamming distances from current solution to current record.
"
Base.@kwdef mutable struct SolverContext
	#входные данные
	instance::KnapsackInstance
	#параметры поиска
	penaltyfactor::Float64 = 0
	inftolerance::Int64 = 0
	numofflips::Int64 = 21
	numofswaps::Int64 = 21
	randomseed::Int64 = 0
	#критерии остановки
	numofiters::Int64 = 10000
	functionevaluations = 10000
	#данные о ходе поиска
	objectivegraph::Vector{Float64} = []
	infeasibilitygraph::Vector{Float64} = []
	recordupdates::Vector{Tuple} = []
	distancetorecordgraph::Vector{Int64} = []
end

# ╔═╡ 263c3995-a588-478d-b54c-7cf71e46e0d9
@doc md"
Stores the information about solution of the knapsack problem solution.
Contains the fields:

`instance` -- parent knapsack problem instance;

`x` -- vector of items amount taken in the solution;
	
`objective` -- the objective function value;
	
`totalweight` -- total weight of the items in the solution;
	
`infeasibility` -- exceeding of the capacity constraint;
	
`isevaluated` -- indicates if the solution is evaluated (in a case of delayed).
	
"
Base.@kwdef mutable struct KnapsackSolution
	instance::KnapsackInstance
	x::Vector{Int8} = zeros(Int8, instance.numofitems)
	objective::Float64 = 0
	totalweight::Float64 = 0
	infeasibility::Float64 = 0
	isevaluated::Bool = false
end

# ╔═╡ f180cd51-6792-445a-8576-92eb0ed59ef9
@doc md"
	copy(original::KnapsackSolution)::KnapsackSolution
Makes a copy of the `original` knapsack solution.
"
function copy(original::KnapsackSolution)::KnapsackSolution
	return KnapsackSolution(
		instance = original.instance,
		x = deepcopy(original.x),
		objective = original.objective,
		totalweight = original.totalweight,
		infeasibility = original.infeasibility,
		isevaluated = original.isevaluated)
end

# ╔═╡ 484e5619-6c48-445c-867b-cff97018004b
@doc md"
	evaluate!(solution::KnapsackSolution)
Fills the fields of the `solution` structure.
"
function evaluate!(solution::KnapsackSolution)
	if solution.isevaluated
		return
	else
		n = solution.instance.numofitems
		v = solution.instance.value
		w = solution.instance.weight
		x = solution.x
		capacity = solution.instance.capacity
		
		solution.objective = 0
		solution.infeasibility = 0
		solution.totalweight = 0
		for i in 1:n
			solution.objective += v[i] * x[i]
			solution.totalweight += w[i] * x[i]
		end
		solution.infeasibility = max(0, solution.totalweight - capacity)
		solution.isevaluated = true
	end
end

# ╔═╡ cd9d6650-3a03-49fd-b5bb-05fd2f13c24d
function greedyInitialSolution(kpinstance::KnapsackInstance)::KnapsackSolution
	emptysol = KnapsackSolution(instance = kpinstance)
	# вводим массив "попробованных" предметов
	tried_x = zeros(Int8, kpinstance.numofitems)
	# внешний цикл по i - не более стольких предметов мы возьмем
	# внутренний цикл по j - выбираем следующий из невзятых предметов с большей 		# ценностью
	current_weight = 0
	for i in 1:kpinstance.numofitems
		max_ro = 0.0
		current_x = 0
		for j in 1:kpinstance.numofitems
			if tried_x[j] == 0
				if max_ro  <= kpinstance.value[j] 
					max_ro = kpinstance.value[j] 
					current_x = j
				end
			end
		end
		# отмечаем, что мы пытаемся добавить этот элемент
		if current_x !=0	
			tried_x[current_x] = 1
			if kpinstance.weight[current_x]+current_weight <= kpinstance.capacity
				emptysol.x[current_x]=1
				current_weight = kpinstance.weight[current_x]+current_weight
			end
		end
	end
	evaluate!(emptysol)
	return emptysol
end	

# ╔═╡ 038f5ca9-1e65-4be9-84fe-6351acfb8b39
function grasp(kpinstance::KnapsackInstance, k::Int64)::KnapsackSolution
	emptysol = KnapsackSolution(instance = kpinstance)
	# вводим массив "свободных" предметов
	freex=[]
	for i in 1:kpinstance.numofitems
		append!(freex,i)
	end
	# выбираем к предметов из свободных, затем берем из них предмет с наибольшей 		# плотностью и пытаемся впихнуть в рюкзак. Если не получается - останавливаем цикл
	current_weight = 0
	while (true)
		idx = []
		for iter in 1:k
			if (freex!=[])
				random_x = rand(freex)
				append!(idx,random_x)
				deleteat!(freex, freex.== random_x)
			end
		end
		maxvalue = 0.0
		maxx = 0
		for i in idx	
			if kpinstance.value[i] / kpinstance.weight[i] > maxvalue 
				maxvalue = kpinstance.value[i] / kpinstance.weight[i]
				maxx = i
			end
		end
		# если всё влезло
		if maxx==0
			evaluate!(emptysol)
			return emptysol
		end
		if kpinstance.capacity >= current_weight + kpinstance.weight[maxx]
			emptysol.x[maxx] = 1
			current_weight = current_weight + kpinstance.weight[maxx]
			deleteat!(idx,idx.==maxx)
			for i in idx
				append!(freex,i)
			end
		else
			evaluate!(emptysol)
			return emptysol
		end
	end
end	

# ╔═╡ 98fc97fd-70a7-4f5b-927b-e4070d365330
@doc md"
	provideInitialSolution(kpinstance::KnapsackInstance)
Fills the fields of the `solution` structure.
"
function provideInitialSolution(kpinstance::KnapsackInstance)::KnapsackSolution
	emptysol = KnapsackSolution(instance = kpinstance)
	evaluate!(emptysol)
	return emptysol
end	

# ╔═╡ aca6ca1d-4ed4-4fff-ac27-c4dbc735de5e
@doc md"
	tryFlip(solution::KnapsackSolution, flipidx::Int64)
Computes the changes of objective function and `solution` infeasibility resulted from the flip in the `flipidx`.
"
function tryFlip(solution::KnapsackSolution, flipidx::Int64)
	if !solution.isevaluated
		evaluate!(solution)
	end

	v = solution.instance.value
	w = solution.instance.weight
	x = solution.x

	Δobjective = v[flipidx] * (1 - 2 * x[flipidx])
	Δtotalweight = w[flipidx] * (1 - 2 * x[flipidx])
	Δinfeasibility = max(0, solution.totalweight + Δtotalweight - solution.instance.capacity) - solution.infeasibility

	return Δobjective, Δinfeasibility
end

# ╔═╡ 2f1f200e-ee28-47be-b928-3bd5b6f6ee2d
function bestallFlipNeighbor!(cursolution::KnapsackSolution, solvercontext::SolverContext)
		bestflip = -1
		flipimp = -Inf
		dim = length(cursolution.x)

		for fliptry in 1:solvercontext.numofflips
			#if solvercontext.functionevaluations == 0
			#	break
			#end
			#solvercontext.functionevaluations -= 1
			
			flipidx = fliptry
			Δobj, Δinf = tryFlip(cursolution, flipidx)
			penalizedimp = Δobj - solvercontext.penaltyfactor * Δinf

			if (cursolution.infeasibility + Δinf <= solvercontext.inftolerance) & (flipimp < penalizedimp)
				bestflip = flipidx
				flipimp = penalizedimp
			end
		end
	return bestflip, flipimp
end

# ╔═╡ d5f1e93f-3577-4bde-8cf3-541ed515dc7b
@doc md"
	bestFlipNeighbor!(cursolution::KnapsackSolution, solvercontext::SolverContext)
Finds the best flip neighbor out of `solvercontext.numofflips` randomly chosen ones.
# Arguments
`cursolution` -- the center of the neighborhood;

`solvercontext` -- solver parameters.
"
function bestFlipNeighbor!(cursolution::KnapsackSolution, solvercontext::SolverContext)
		bestflip = -1
		flipimp = -Inf
		dim = length(cursolution.x)

		for fliptry in 1:solvercontext.numofflips
			if solvercontext.functionevaluations == 0
				break
			end
			solvercontext.functionevaluations -= 1
			
			flipidx = rand(1:dim)
			Δobj, Δinf = tryFlip(cursolution, flipidx)
			penalizedimp = Δobj - solvercontext.penaltyfactor * Δinf

			if (cursolution.infeasibility + Δinf <= solvercontext.inftolerance) & (flipimp < penalizedimp)
				bestflip = flipidx
				flipimp = penalizedimp
			end
		end
	return bestflip, flipimp
end

# ╔═╡ a22d3676-546d-483d-b05d-f4d7f300f201
@doc md"
	applyFlip!(solution::KnapsackSolution, flipidx::Int64)
Modifies the `solution` by applying flip at `flipidx`.
"
function applyFlip!(solution::KnapsackSolution, flipidx::Int64)
	if !solution.isevaluated
		evaluate!(solution)
	end

	v = solution.instance.value
	w = solution.instance.weight
	x = solution.x

	solution.objective += v[flipidx] * (1 - 2 * x[flipidx])
	solution.totalweight += w[flipidx] * (1 - 2 * x[flipidx])
	solution.infeasibility = max(0, solution.totalweight - solution.instance.capacity)
	solution.x[flipidx] = 1 - solution.x[flipidx]

	return solution
end

# ╔═╡ 2fc1b08c-58e5-4ce1-bef6-b266bdd04b40
@doc md"
	trySwap(solution::KnapsackSolution, i1::Int64, i0::Int64)
Computes the changes of objective function and `solution` infeasibility resulted from the swap of one at `i1` and zero at `i0`.
"
function trySwap(solution::KnapsackSolution, i1::Int64, i0::Int64)
	if !solution.isevaluated
		evaluate!(solution)
	end

	v = solution.instance.value
	w = solution.instance.weight
	x = solution.x
	
	Δobjective = v[i1] * (1 - 2 * x[i1]) + v[i0] * (1 - 2 * x[i0])
	
	Δtotalweight = w[i1] * (1 - 2 * x[i1]) + w[i0] * (1 - 2 * x[i0])
	
	Δinfeasibility = max(0, solution.totalweight + Δtotalweight - solution.instance.capacity) - solution.infeasibility

	return Δobjective, Δinfeasibility
end

# ╔═╡ 63dd5f18-b540-48b7-b02d-e7b950a10d49
function bestallSwapNeighbor!(cursolution::KnapsackSolution, solvercontext::SolverContext)
		bestswap = []
		swapimp = -Inf
		oneidxlist = []
		zeroidxlist = []
		dim = length(cursolution.x)
		for i in 1:dim
			if cursolution.x[i] == 0
				append!(zeroidxlist, i)
			else
				append!(oneidxlist, i)
			end
		end
		
		for i in oneidxlist
			for j in zeroidxlist
				#if solvercontext.functionevaluations == 0
				#	break
				#end
				#solvercontext.functionevaluations -= 1
				
				swapidx1 = i
				swapidx0 = j
				
				Δobj, Δinf = trySwap(cursolution, swapidx1, swapidx0)
				penalizedimp = Δobj + solvercontext.penaltyfactor * Δinf
	
				if (cursolution.infeasibility + Δinf <= solvercontext.inftolerance) & (swapimp < penalizedimp)
					bestswap = [swapidx1, swapidx0]
					swapimp = penalizedimp
				end
			end
		end
	return bestswap, swapimp
end

# ╔═╡ dbc4d95a-8e36-4ef7-b769-d9d5e241456b
@doc md"
	bestSwapNeighbor!(cursolution::KnapsackSolution, solvercontext::SolverContext)
Finds the best swap neighbor out of `solvercontext.numofswaps` randomly chosen ones.
# Arguments
`cursolution` -- the center of the neighborhood;

`solvercontext` -- solver parameters.
"
function bestSwapNeighbor!(cursolution::KnapsackSolution, solvercontext::SolverContext)
		bestswap = []
		swapimp = -Inf
		oneidxlist = []
		zeroidxlist = []
		dim = length(cursolution.x)
		for i in 1:dim
			if cursolution.x[i] == 0
				append!(zeroidxlist, i)
			else
				append!(oneidxlist, i)
			end
		end
		
		for swaptry in 1:solvercontext.numofswaps
			if solvercontext.functionevaluations == 0
				break
			end
			solvercontext.functionevaluations -= 1
			
			swapidx1 = oneidxlist[rand(1:length(oneidxlist))]
			swapidx0 = zeroidxlist[rand(1:length(zeroidxlist))]
			
			Δobj, Δinf = trySwap(cursolution, swapidx1, swapidx0)
			penalizedimp = Δobj + solvercontext.penaltyfactor * Δinf

			if (cursolution.infeasibility + Δinf <= solvercontext.inftolerance) & (swapimp < penalizedimp)
				bestswap = [swapidx1, swapidx0]
				swapimp = penalizedimp
			end
		end
	return bestswap, swapimp
end

# ╔═╡ b9159065-7f65-40a8-88d0-91d4c68310f2
@doc md"
	applySwap!(solution::KnapsackSolution, swapidx1::Int64, swapidx0::Int64)
Modifies the `solution` by applying swap of components `swapidx1` and `swapidx0`.
"
function applySwap!(solution::KnapsackSolution, swapidx1::Int64, swapidx0::Int64)
	if !solution.isevaluated
		evaluate!(solution)
	end


	solution.objective += solution.instance.value[swapidx1] * (1 - 2 * solution.x[swapidx1]) + solution.instance.value[swapidx0] * (1 - 2 * solution.x[swapidx0])
	
	solution.totalweight += solution.instance.weight[swapidx1] * (1 - 2 * solution.x[swapidx1]) + solution.instance.weight[swapidx0] * (1 - 2 * solution.x[swapidx0])
	
	solution.infeasibility = max(0, solution.infeasibility - solution.instance.capacity)

	solution.x[swapidx1] = 1 - solution.x[swapidx1]
	solution.x[swapidx0] = 1 - solution.x[swapidx0]

	return solution
end

# ╔═╡ e639533d-12fe-4cd1-a46a-204514e2de26
function solveKPwithLS(solvercontext::SolverContext)::KnapsackSolution
	kpinstance = solvercontext.instance
	Random.seed!(solvercontext.randomseed)
	
    initsol = provideInitialSolution(kpinstance)
	cursol = initsol
	record = copy(cursol)

	iterations = 0
	while (iterations < solvercontext.numofiters) & (solvercontext.functionevaluations > 0)
		iterations += 1
		push!(solvercontext.objectivegraph, cursol.objective)
		push!(solvercontext.distancetorecordgraph, hamming(cursol.x, record.x))

		bestflip, flipimp = bestFlipNeighbor!(cursol, solvercontext)
		if bestflip != -1
			applyFlip!(cursol, bestflip)
			if cursol.objective > record.objective
				record = copy(cursol)
				push!(solvercontext.recordupdates, (iterations + 1, record.objective))
			end
			if flipimp > 0
				continue
			end
		end


		bestswap, swapimp = bestSwapNeighbor!(cursol, solvercontext)
		if length(bestswap) > 0
			applySwap!(cursol, bestswap[1], bestswap[2])
			if cursol.objective > record.objective
				record = copy(cursol)
				push!(solvercontext.recordupdates, (iterations + 1, record.objective))
			end
		end
	end
	return record
end

# ╔═╡ 991c3bb7-8175-4bf3-b6c3-47e8a9652231
begin
	solvercontext = SolverContext(
		instance = instance, 
		randomseed = 1,
		numofflips = 21,
		numofswaps = 21,
		inftolerance = 0
	)

	lssol = solveKPwithLS(solvercontext)
	plot1 = plot(
		solvercontext.objectivegraph,
		label = "Current solution",
		legend = :bottomright
	)
	plot1 = scatter!(plot1, 
		solvercontext.recordupdates, 
		markerstrokewidth = 0, 
		label = "Record update"
	)

	
	plot2 = plot(
		solvercontext.distancetorecordgraph,
		label = "Distance to record solution",
		linecolor = :green
	)
	

	plot(plot1, plot2, layout = (2, 1))
end

# ╔═╡ a10768c2-3f9b-4fba-bc0b-9d327eee3871
begin
	runs = []
	for run in 1:100
		solvercontext = SolverContext(
			instance = instance, 
			randomseed = run,
			numofflips = 21,
			numofswaps = 21
		)
		lssol = solveKPwithLS(solvercontext)
		push!(runs, lssol.objective)
	end
	mean = Statistics.mean(runs)
	std = Statistics.std(runs)
	with_terminal() do
		println("Mean: $mean\tStd: $std")
	end
end

# ╔═╡ 2113f032-9c95-4102-9915-538a0771669f
function greedy_solveKPwithLS(solvercontext::SolverContext)::KnapsackSolution
	kpinstance = solvercontext.instance
	Random.seed!(solvercontext.randomseed)
	
    initsol = greedyInitialSolution(kpinstance)
	cursol = copy(initsol)
	record = copy(cursol)

	iterations = 0
	# так как жадный алгоритм с плотностями дал оптимальное решение, то обновлений рекорда внутри цикла не будет, и чтобы плоттер не крашился, я введу рекорд при инициализации
	push!(solvercontext.recordupdates, (iterations +1 , cursol.objective))
	while (iterations < solvercontext.numofiters) & (solvercontext.functionevaluations > 0)
		iterations += 1
		push!(solvercontext.objectivegraph, cursol.objective)
		push!(solvercontext.distancetorecordgraph, hamming(cursol.x, record.x))
		bestflip, flipimp = bestFlipNeighbor!(cursol, solvercontext)
		if bestflip != -1
			applyFlip!(cursol, bestflip)
			if cursol.objective > record.objective
				record = copy(cursol)
				push!(solvercontext.recordupdates, (iterations + 1, record.objective))
			end
			if flipimp > 0
				continue
			end
		end


		bestswap, swapimp = bestSwapNeighbor!(cursol, solvercontext)
		if length(bestswap) > 0
			applySwap!(cursol, bestswap[1], bestswap[2])
			if cursol.objective > record.objective
				record = copy(cursol)
				push!(solvercontext.recordupdates, (iterations + 1, record.objective))
			end
		end
	end
	return record
end

# ╔═╡ 81169506-db07-44ad-bb53-d9b3711cce92
begin
	t1_solvercontext = SolverContext(
		instance = instance, 
		randomseed = 1,
		numofflips = 21,
		numofswaps = 21,
		inftolerance = 0
	)

	t1_lssol = greedy_solveKPwithLS(t1_solvercontext)
	t1_plot1 = plot(
		t1_solvercontext.objectivegraph,
		label = "Current solution",
		legend = :bottomright
	)
	t1_plot1 = scatter!(t1_plot1, 
		t1_solvercontext.recordupdates, 
		markerstrokewidth = 0, 
		label = "Record update"
	)

	
	t1_plot2 = plot(
		t1_solvercontext.distancetorecordgraph,
		label = "Distance to record solution",
		linecolor = :green
	)
	

	plot(t1_plot1, t1_plot2, layout = (2, 1))
end

# ╔═╡ 771d8c20-8e34-4560-9f86-f5179e5a3072
begin
	t1_runs = []
	for t1_run in 1:100
		t1_solvercontext = SolverContext(
			instance = instance, 
			randomseed = t1_run,
			numofflips = 21,
			numofswaps = 21
		)
		t1_lssol = greedy_solveKPwithLS(t1_solvercontext)
		push!(t1_runs, t1_lssol.objective)
	end
	t1_mean = Statistics.mean(t1_runs)
	t1_std = Statistics.std(t1_runs)
	with_terminal() do
		println("Mean: $t1_mean\tStd: $t1_std")
	end
end

# ╔═╡ ffcb6c02-7981-4791-a409-973ec5394539
function fa_solveKPwithLS(solvercontext::SolverContext)::KnapsackSolution
	kpinstance = solvercontext.instance
	Random.seed!(solvercontext.randomseed)
	
    initsol = provideInitialSolution(kpinstance)
	#initsol = solveKPwithLS(solvercontext)
	cursol = copy(initsol)
	record = copy(cursol)
	flag = 1
	iterations = 0
	# так как жадный алгоритм с плотностями дал оптимальное решение, то обновлений рекорда внутри цикла не будет, и чтобы плоттер не крашился, я введу рекорд при инициализации
	#push!(solvercontext.recordupdates, (iterations +1 , cursol.objective))
	while (iterations < solvercontext.numofiters) & (solvercontext.functionevaluations  > 0) && (flag == 1)
		current_obj = cursol.objective
		flip_cursol = copy(cursol)
		swap_cursol = copy(cursol)
		iterations += 1
		push!(solvercontext.objectivegraph, cursol.objective)
		push!(solvercontext.distancetorecordgraph, hamming(cursol.x, record.x))
		bestflip, flipimp = bestallFlipNeighbor!(cursol, solvercontext)
		if bestflip != -1
			applyFlip!(flip_cursol, bestflip)
		end
		bestswap, swapimp = bestallSwapNeighbor!(cursol, solvercontext)
		if length(bestswap) > 0
			applySwap!(swap_cursol, bestswap[1], bestswap[2])
		end
		if swap_cursol.objective > flip_cursol.objective
			cursol = copy(swap_cursol)
		else
			cursol = copy(flip_cursol)
		end
		if cursol.objective > record.objective
			record = copy(cursol)
			push!(solvercontext.recordupdates, (iterations + 1, record.objective))
		end
		if cursol.objective <= current_obj
			flag = 0
		end
		
	end
	#push!(solvercontext.objectivegraph, cursol.objective)
	#push!(solvercontext.distancetorecordgraph, hamming(cursol.x, record.x))
	return record
end

# ╔═╡ aa061f9e-7dc2-41a6-817a-cfa11d403f6b
begin
	t2_solvercontext = SolverContext(
		instance = instance, 
		randomseed = 1,
		numofflips = 21,
		numofswaps = 21,
		inftolerance = 0
	)

	t2_lssol = fa_solveKPwithLS(t2_solvercontext)
	t2_plot1 = plot(
		t2_solvercontext.objectivegraph,
		label = "Current solution",
		legend = :bottomright
	)
	t2_plot1 = scatter!(t2_plot1, 
		t2_solvercontext.recordupdates, 
		markerstrokewidth = 0, 
		label = "Record update"
	)

	
	t2_plot2 = plot(
		t2_solvercontext.distancetorecordgraph,
		label = "Distance to record solution",
		linecolor = :green
	)
	

	plot(t2_plot1, t2_plot2, layout = (2, 1))
end

# ╔═╡ d8e29358-e6ca-42ca-a6d4-657995bdc7b8
begin
	t2_runs = []
	for t2_run in 1:300
		t2_solvercontext = SolverContext(
			instance = instance, 
			randomseed = t2_run,
			numofflips = 21,
			numofswaps = 21
		)
		t2_lssol = fa_solveKPwithLS(t2_solvercontext)
		push!(t2_runs, t2_lssol.objective)
	end
	t2_mean = Statistics.mean(t2_runs)
	t2_std = Statistics.std(t2_runs)
	with_terminal() do
		println("Mean: $t2_mean\tStd: $t2_std")
	end
end

# ╔═╡ 6d0c651f-a7f8-4e65-8e11-2a43b761aa74
function grasp_solveKPwithLS(solvercontext::SolverContext, k::Int64, seed::Integer=solvercontext.randomseed)::KnapsackSolution
	kpinstance = solvercontext.instance
	Random.seed!(seed)
	
    initsol = grasp(kpinstance,k)
	#initsol = solveKPwithLS(solvercontext)
	cursol = copy(initsol)
	record = copy(cursol)
	flag = 1
	iterations = 0
	# так как жадный алгоритм с плотностями дал оптимальное решение, то обновлений рекорда внутри цикла не будет, и чтобы плоттер не крашился, я введу рекорд при инициализации
	#push!(solvercontext.recordupdates, (iterations +1 , cursol.objective))
	while (iterations < solvercontext.numofiters) & (solvercontext.functionevaluations  > 0) && (flag == 1)
		current_obj = cursol.objective
		flip_cursol = copy(cursol)
		swap_cursol = copy(cursol)
		iterations += 1
		push!(solvercontext.objectivegraph, cursol.objective)
		push!(solvercontext.distancetorecordgraph, hamming(cursol.x, record.x))
		bestflip, flipimp = bestallFlipNeighbor!(cursol, solvercontext)
		if bestflip != -1
			applyFlip!(flip_cursol, bestflip)
		end
		bestswap, swapimp = bestallSwapNeighbor!(cursol, solvercontext)
		if length(bestswap) > 0
			applySwap!(swap_cursol, bestswap[1], bestswap[2])
		end
		if swap_cursol.objective > flip_cursol.objective
			cursol = copy(swap_cursol)
		else
			cursol = copy(flip_cursol)
		end
		if cursol.objective > record.objective
			record = copy(cursol)
			push!(solvercontext.recordupdates, (iterations + 1, record.objective))
		end
		if cursol.objective <= current_obj
			flag = 0
		end
		
	end
	#push!(solvercontext.objectivegraph, cursol.objective)
	#push!(solvercontext.distancetorecordgraph, hamming(cursol.x, record.x))
	return record
end

# ╔═╡ 69dd2e8d-d1c0-45ee-8b17-7a23424c05d8
function multistart_grasp(solvercontext::SolverContext, k::Int64, numofstarts::Int64)::KnapsackSolution
	kpinstance = solvercontext.instance
	record = provideInitialSolution(kpinstance)
	maxval = 0
	Random.seed!(solvercontext.randomseed)
	for i in 1:numofstarts
		t = grasp_solveKPwithLS(solvercontext,k,rand(1:numofstarts))
		if t.objective>maxval
			maxval = t.objective
			record = copy(t)
		end
		
	end
	return record
end
		

# ╔═╡ 253f1853-d8a7-4921-9fd4-e0f8c1e2bb36
begin
	t3_runs = []
	for t3_run in 1:100
		t3_solvercontext = SolverContext(
			instance = instance, 
			randomseed = t3_run,
			numofflips = 21,
			numofswaps = 21
		)
		t3_lssol = multistart_grasp(t3_solvercontext, 65,4)
		push!(t3_runs, t3_lssol.objective)
	end
	t3_mean = Statistics.mean(t3_runs)
	t3_std = Statistics.std(t3_runs)
	with_terminal() do
		println("Mean: $t3_mean\tStd: $t3_std")
	end
end

# ╔═╡ faef833a-b9a1-4d2a-97a7-f9653d953fb1
begin
	t3_solvercontext = SolverContext(
		instance = instance, 
		randomseed = 5,
		numofflips = 21,
		numofswaps = 21,
		inftolerance = 0
	)

	t3_lssol = grasp_solveKPwithLS(t3_solvercontext,10)
	t3_plot1 = plot(
		t3_solvercontext.objectivegraph,
		label = "Current solution",
		legend = :bottomright
	)
	t3_plot1 = scatter!(t3_plot1, 
		t3_solvercontext.recordupdates, 
		markerstrokewidth = 0, 
		label = "Record update"
	)

	
	t3_plot2 = plot(
		t3_solvercontext.distancetorecordgraph,
		label = "Distance to record solution",
		linecolor = :green
	)
	

	plot(t3_plot1, t3_plot2, layout = (2, 1))
end

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
CSV = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
Distances = "b4f34e82-e78d-54a5-968a-f98e89d6e8f7"
GLPK = "60bf3e95-4087-53dc-ae20-288a0d20c6a6"
Interpolations = "a98d9a8b-a2ab-59e6-89dd-64a1c18fca59"
JuMP = "4076af6c-e467-56ae-b986-b466b2749572"
Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
Polynomials = "f27b6e38-b328-58d1-80ce-0feddd5e7a45"
Random = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
Tables = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"

[compat]
CSV = "~0.9.11"
DataFrames = "~1.3.0"
Distances = "~0.10.7"
GLPK = "~0.15.2"
Interpolations = "~0.13.5"
JuMP = "~0.22.1"
Plots = "~1.25.2"
PlutoUI = "~0.7.23"
Polynomials = "~2.0.18"
Tables = "~1.6.1"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

[[AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "abb72771fd8895a7ebd83d5632dc4b989b022b5b"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.1.2"

[[Adapt]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "84918055d15b3114ede17ac6a7182f68870c16f7"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "3.3.1"

[[ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"

[[Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[AxisAlgorithms]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "WoodburyMatrices"]
git-tree-sha1 = "66771c8d21c8ff5e3a93379480a2307ac36863f7"
uuid = "13072b0f-2c55-5437-9ae7-d433b7a33950"
version = "1.0.1"

[[Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[BenchmarkTools]]
deps = ["JSON", "Logging", "Printf", "Profile", "Statistics", "UUIDs"]
git-tree-sha1 = "940001114a0147b6e4d10624276d56d531dd9b49"
uuid = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
version = "1.2.2"

[[BinaryProvider]]
deps = ["Libdl", "Logging", "SHA"]
git-tree-sha1 = "ecdec412a9abc8db54c0efc5548c64dfce072058"
uuid = "b99e7846-7c00-51b0-8f62-c81ae34c0232"
version = "0.5.10"

[[Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "19a35467a82e236ff51bc17a3a44b69ef35185a2"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.8+0"

[[CEnum]]
git-tree-sha1 = "215a9aa4a1f23fbd05b92769fdd62559488d70e9"
uuid = "fa961155-64e5-5f13-b03f-caf6b980ea82"
version = "0.4.1"

[[CSV]]
deps = ["CodecZlib", "Dates", "FilePathsBase", "InlineStrings", "Mmap", "Parsers", "PooledArrays", "SentinelArrays", "Tables", "Unicode", "WeakRefStrings"]
git-tree-sha1 = "49f14b6c56a2da47608fe30aed711b5882264d7a"
uuid = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
version = "0.9.11"

[[Cairo_jll]]
deps = ["Artifacts", "Bzip2_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "LZO_jll", "Libdl", "Pixman_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "4b859a208b2397a7a623a03449e4636bdb17bcf2"
uuid = "83423d85-b0ee-5818-9007-b63ccbeb887a"
version = "1.16.1+1"

[[Calculus]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "f641eb0a4f00c343bbc32346e1217b86f3ce9dad"
uuid = "49dc2e85-a5d0-5ad3-a950-438e2897f1b9"
version = "0.5.1"

[[ChainRulesCore]]
deps = ["Compat", "LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "4c26b4e9e91ca528ea212927326ece5918a04b47"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.11.2"

[[ChangesOfVariables]]
deps = ["ChainRulesCore", "LinearAlgebra", "Test"]
git-tree-sha1 = "bf98fa45a0a4cee295de98d4c1462be26345b9a1"
uuid = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
version = "0.1.2"

[[CodecBzip2]]
deps = ["Bzip2_jll", "Libdl", "TranscodingStreams"]
git-tree-sha1 = "2e62a725210ce3c3c2e1a3080190e7ca491f18d7"
uuid = "523fee87-0ab8-5b00-afb7-3ecf72e48cfd"
version = "0.7.2"

[[CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "ded953804d019afa9a3f98981d99b33e3db7b6da"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.0"

[[ColorSchemes]]
deps = ["ColorTypes", "Colors", "FixedPointNumbers", "Random"]
git-tree-sha1 = "a851fec56cb73cfdf43762999ec72eff5b86882a"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.15.0"

[[ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "024fe24d83e4a5bf5fc80501a314ce0d1aa35597"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.0"

[[Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "417b0ed7b8b838aa6ca0a87aadf1bb9eb111ce40"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.12.8"

[[CommonSubexpressions]]
deps = ["MacroTools", "Test"]
git-tree-sha1 = "7b8a93dba8af7e3b42fecabf646260105ac373f7"
uuid = "bbf7d656-a473-5ed7-a52c-81e309532950"
version = "0.3.0"

[[Compat]]
deps = ["Base64", "Dates", "DelimitedFiles", "Distributed", "InteractiveUtils", "LibGit2", "Libdl", "LinearAlgebra", "Markdown", "Mmap", "Pkg", "Printf", "REPL", "Random", "SHA", "Serialization", "SharedArrays", "Sockets", "SparseArrays", "Statistics", "Test", "UUIDs", "Unicode"]
git-tree-sha1 = "44c37b4636bc54afac5c574d2d02b625349d6582"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "3.41.0"

[[CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"

[[Contour]]
deps = ["StaticArrays"]
git-tree-sha1 = "9f02045d934dc030edad45944ea80dbd1f0ebea7"
uuid = "d38c429a-6771-53c6-b99e-75d170b6e991"
version = "0.5.7"

[[Crayons]]
git-tree-sha1 = "3f71217b538d7aaee0b69ab47d9b7724ca8afa0d"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.0.4"

[[DataAPI]]
git-tree-sha1 = "cc70b17275652eb47bc9e5f81635981f13cea5c8"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.9.0"

[[DataFrames]]
deps = ["Compat", "DataAPI", "Future", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "Markdown", "Missings", "PooledArrays", "PrettyTables", "Printf", "REPL", "Reexport", "SortingAlgorithms", "Statistics", "TableTraits", "Tables", "Unicode"]
git-tree-sha1 = "2e993336a3f68216be91eb8ee4625ebbaba19147"
uuid = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
version = "1.3.0"

[[DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "3daef5523dd2e769dad2365274f760ff5f282c7d"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.11"

[[DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[DelimitedFiles]]
deps = ["Mmap"]
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"

[[DiffResults]]
deps = ["StaticArrays"]
git-tree-sha1 = "c18e98cba888c6c25d1c3b048e4b3380ca956805"
uuid = "163ba53b-c6d8-5494-b064-1a9d43ac40c5"
version = "1.0.3"

[[DiffRules]]
deps = ["LogExpFunctions", "NaNMath", "Random", "SpecialFunctions"]
git-tree-sha1 = "9bc5dac3c8b6706b58ad5ce24cffd9861f07c94f"
uuid = "b552c78f-8df3-52c6-915a-8e097449b14b"
version = "1.9.0"

[[Distances]]
deps = ["LinearAlgebra", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "3258d0659f812acde79e8a74b11f17ac06d0ca04"
uuid = "b4f34e82-e78d-54a5-968a-f98e89d6e8f7"
version = "0.10.7"

[[Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "b19534d1895d702889b219c382a6e18010797f0b"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.8.6"

[[Downloads]]
deps = ["ArgTools", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"

[[EarCut_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "3f3a2501fa7236e9b911e0f7a588c657e822bb6d"
uuid = "5ae413db-bbd1-5e63-b57d-d24a61df00f5"
version = "2.2.3+0"

[[Expat_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b3bfd02e98aedfa5cf885665493c5598c350cd2f"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.2.10+0"

[[ExprTools]]
git-tree-sha1 = "b7e3d17636b348f005f11040025ae8c6f645fe92"
uuid = "e2ba6199-217a-4e67-a87a-7c52f15ade04"
version = "0.1.6"

[[FFMPEG]]
deps = ["FFMPEG_jll"]
git-tree-sha1 = "b57e3acbe22f8484b4b5ff66a7499717fe1a9cc8"
uuid = "c87230d0-a227-11e9-1b43-d7ebe4e7570a"
version = "0.4.1"

[[FFMPEG_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "LAME_jll", "Libdl", "Ogg_jll", "OpenSSL_jll", "Opus_jll", "Pkg", "Zlib_jll", "libass_jll", "libfdk_aac_jll", "libvorbis_jll", "x264_jll", "x265_jll"]
git-tree-sha1 = "d8a578692e3077ac998b50c0217dfd67f21d1e5f"
uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"
version = "4.4.0+0"

[[FilePathsBase]]
deps = ["Compat", "Dates", "Mmap", "Printf", "Test", "UUIDs"]
git-tree-sha1 = "04d13bfa8ef11720c24e4d840c0033d145537df7"
uuid = "48062228-2e41-5def-b9a4-89aafe57970f"
version = "0.9.17"

[[FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[Fontconfig_jll]]
deps = ["Artifacts", "Bzip2_jll", "Expat_jll", "FreeType2_jll", "JLLWrappers", "Libdl", "Libuuid_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "21efd19106a55620a188615da6d3d06cd7f6ee03"
uuid = "a3f928ae-7b40-5064-980b-68af3947d34b"
version = "2.13.93+0"

[[Formatting]]
deps = ["Printf"]
git-tree-sha1 = "8339d61043228fdd3eb658d86c926cb282ae72a8"
uuid = "59287772-0a20-5a39-b81b-1366585eb4c0"
version = "0.4.2"

[[ForwardDiff]]
deps = ["CommonSubexpressions", "DiffResults", "DiffRules", "LinearAlgebra", "LogExpFunctions", "NaNMath", "Preferences", "Printf", "Random", "SpecialFunctions", "StaticArrays"]
git-tree-sha1 = "2b72a5624e289ee18256111657663721d59c143e"
uuid = "f6369f11-7733-5829-9624-2563aa707210"
version = "0.10.24"

[[FreeType2_jll]]
deps = ["Artifacts", "Bzip2_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "87eb71354d8ec1a96d4a7636bd57a7347dde3ef9"
uuid = "d7e528f0-a631-5988-bf34-fe36492bcfd7"
version = "2.10.4+0"

[[FriBidi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "aa31987c2ba8704e23c6c8ba8a4f769d5d7e4f91"
uuid = "559328eb-81f9-559d-9380-de523a88c83c"
version = "1.0.10+0"

[[Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[GLFW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libglvnd_jll", "Pkg", "Xorg_libXcursor_jll", "Xorg_libXi_jll", "Xorg_libXinerama_jll", "Xorg_libXrandr_jll"]
git-tree-sha1 = "0c603255764a1fa0b61752d2bec14cfbd18f7fe8"
uuid = "0656b61e-2033-5cc2-a64a-77c0f6c09b89"
version = "3.3.5+1"

[[GLPK]]
deps = ["BinaryProvider", "CEnum", "GLPK_jll", "Libdl", "MathOptInterface"]
git-tree-sha1 = "ab6d06aa06ce3de20a82de5f7373b40796260f72"
uuid = "60bf3e95-4087-53dc-ae20-288a0d20c6a6"
version = "0.15.2"

[[GLPK_jll]]
deps = ["Artifacts", "GMP_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "fe68622f32828aa92275895fdb324a85894a5b1b"
uuid = "e8aa6df9-e6ca-548a-97ff-1f85fc5b8b98"
version = "5.0.1+0"

[[GMP_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "781609d7-10c4-51f6-84f2-b8444358ff6d"

[[GR]]
deps = ["Base64", "DelimitedFiles", "GR_jll", "HTTP", "JSON", "Libdl", "LinearAlgebra", "Pkg", "Printf", "Random", "Serialization", "Sockets", "Test", "UUIDs"]
git-tree-sha1 = "30f2b340c2fff8410d89bfcdc9c0a6dd661ac5f7"
uuid = "28b8d3ca-fb5f-59d9-8090-bfdbd6d07a71"
version = "0.62.1"

[[GR_jll]]
deps = ["Artifacts", "Bzip2_jll", "Cairo_jll", "FFMPEG_jll", "Fontconfig_jll", "GLFW_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libtiff_jll", "Pixman_jll", "Pkg", "Qt5Base_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "fd75fa3a2080109a2c0ec9864a6e14c60cca3866"
uuid = "d2c73de3-f751-5644-a686-071e5b155ba9"
version = "0.62.0+0"

[[GeometryBasics]]
deps = ["EarCut_jll", "IterTools", "LinearAlgebra", "StaticArrays", "StructArrays", "Tables"]
git-tree-sha1 = "58bcdf5ebc057b085e58d95c138725628dd7453c"
uuid = "5c1252a2-5f33-56bf-86c9-59e7332b4326"
version = "0.4.1"

[[Gettext_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "9b02998aba7bf074d14de89f9d37ca24a1a0b046"
uuid = "78b55507-aeef-58d4-861c-77aaff3498b1"
version = "0.21.0+0"

[[Glib_jll]]
deps = ["Artifacts", "Gettext_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Libiconv_jll", "Libmount_jll", "PCRE_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "a32d672ac2c967f3deb8a81d828afc739c838a06"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.68.3+2"

[[Graphite2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "344bf40dcab1073aca04aa0df4fb092f920e4011"
uuid = "3b182d85-2403-5c21-9c21-1e1f0cc25472"
version = "1.3.14+0"

[[Grisu]]
git-tree-sha1 = "53bb909d1151e57e2484c3d1b53e19552b887fb2"
uuid = "42e2da0e-8278-4e71-bc24-59509adca0fe"
version = "1.0.2"

[[HTTP]]
deps = ["Base64", "Dates", "IniFile", "MbedTLS", "Sockets"]
git-tree-sha1 = "c7ec02c4c6a039a98a15f955462cd7aea5df4508"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "0.8.19"

[[HarfBuzz_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "Graphite2_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg"]
git-tree-sha1 = "129acf094d168394e80ee1dc4bc06ec835e510a3"
uuid = "2e76f6c2-a576-52d4-95c1-20adfe4de566"
version = "2.8.1+1"

[[Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "8d511d5b81240fc8e6802386302675bdf47737b9"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.4"

[[HypertextLiteral]]
git-tree-sha1 = "2b078b5a615c6c0396c77810d92ee8c6f470d238"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.3"

[[IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "f7be53659ab06ddc986428d3a9dcc95f6fa6705a"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.2"

[[IniFile]]
deps = ["Test"]
git-tree-sha1 = "098e4d2c533924c921f9f9847274f2ad89e018b8"
uuid = "83e8ac13-25f8-5344-8a64-a9f2b223428f"
version = "0.5.0"

[[InlineStrings]]
deps = ["Parsers"]
git-tree-sha1 = "8d70835a3759cdd75881426fced1508bb7b7e1b6"
uuid = "842dd82b-1e85-43dc-bf29-5d0ee9dffc48"
version = "1.1.1"

[[InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[Interpolations]]
deps = ["AxisAlgorithms", "ChainRulesCore", "LinearAlgebra", "OffsetArrays", "Random", "Ratios", "Requires", "SharedArrays", "SparseArrays", "StaticArrays", "WoodburyMatrices"]
git-tree-sha1 = "b15fc0a95c564ca2e0a7ae12c1f095ca848ceb31"
uuid = "a98d9a8b-a2ab-59e6-89dd-64a1c18fca59"
version = "0.13.5"

[[Intervals]]
deps = ["Dates", "Printf", "RecipesBase", "Serialization", "TimeZones"]
git-tree-sha1 = "323a38ed1952d30586d0fe03412cde9399d3618b"
uuid = "d8418881-c3e1-53bb-8760-2df7ec849ed5"
version = "1.5.0"

[[InverseFunctions]]
deps = ["Test"]
git-tree-sha1 = "a7254c0acd8e62f1ac75ad24d5db43f5f19f3c65"
uuid = "3587e190-3f89-42d0-90ee-14403ec27112"
version = "0.1.2"

[[InvertedIndices]]
git-tree-sha1 = "bee5f1ef5bf65df56bdd2e40447590b272a5471f"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.1.0"

[[IrrationalConstants]]
git-tree-sha1 = "7fd44fd4ff43fc60815f8e764c0f352b83c49151"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.1.1"

[[IterTools]]
git-tree-sha1 = "fa6287a4469f5e048d763df38279ee729fbd44e5"
uuid = "c8e1da08-722c-5040-9ed9-7db0dc04731e"
version = "1.4.0"

[[IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[JLLWrappers]]
deps = ["Preferences"]
git-tree-sha1 = "642a199af8b68253517b80bd3bfd17eb4e84df6e"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.3.0"

[[JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "8076680b162ada2a031f707ac7b4953e30667a37"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.2"

[[JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "d735490ac75c5cb9f1b00d8b5509c11984dc6943"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "2.1.0+0"

[[JuMP]]
deps = ["Calculus", "DataStructures", "ForwardDiff", "JSON", "LinearAlgebra", "MathOptInterface", "MutableArithmetics", "NaNMath", "Printf", "Random", "SparseArrays", "SpecialFunctions", "Statistics"]
git-tree-sha1 = "de9c69c0862be0e11afe5d4aa3426af1d7ecac2c"
uuid = "4076af6c-e467-56ae-b986-b466b2749572"
version = "0.22.1"

[[LAME_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "f6250b16881adf048549549fba48b1161acdac8c"
uuid = "c1c5ebd0-6772-5130-a774-d5fcae4a789d"
version = "3.100.1+0"

[[LERC_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "bf36f528eec6634efc60d7ec062008f171071434"
uuid = "88015f11-f218-50d7-93a8-a6af411a945d"
version = "3.0.0+1"

[[LZO_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e5b909bcf985c5e2605737d2ce278ed791b89be6"
uuid = "dd4b983a-f0e5-5f8d-a1b7-129d4a5fb1ac"
version = "2.10.1+0"

[[LaTeXStrings]]
git-tree-sha1 = "f2355693d6778a178ade15952b7ac47a4ff97996"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.3.0"

[[Latexify]]
deps = ["Formatting", "InteractiveUtils", "LaTeXStrings", "MacroTools", "Markdown", "Printf", "Requires"]
git-tree-sha1 = "a8f4f279b6fa3c3c4f1adadd78a621b13a506bce"
uuid = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
version = "0.15.9"

[[LazyArtifacts]]
deps = ["Artifacts", "Pkg"]
uuid = "4af54fe1-eca0-43a8-85a7-787d91b784e3"

[[LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"

[[LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"

[[LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"

[[Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[Libffi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "0b4a5d71f3e5200a7dff793393e09dfc2d874290"
uuid = "e9f186c6-92d2-5b65-8a66-fee21dc1b490"
version = "3.2.2+1"

[[Libgcrypt_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgpg_error_jll", "Pkg"]
git-tree-sha1 = "64613c82a59c120435c067c2b809fc61cf5166ae"
uuid = "d4300ac3-e22c-5743-9152-c294e39db1e4"
version = "1.8.7+0"

[[Libglvnd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll", "Xorg_libXext_jll"]
git-tree-sha1 = "7739f837d6447403596a75d19ed01fd08d6f56bf"
uuid = "7e76a0d4-f3c7-5321-8279-8d96eeed0f29"
version = "1.3.0+3"

[[Libgpg_error_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c333716e46366857753e273ce6a69ee0945a6db9"
uuid = "7add5ba3-2f88-524e-9cd5-f83b8a55f7b8"
version = "1.42.0+0"

[[Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "42b62845d70a619f063a7da093d995ec8e15e778"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.16.1+1"

[[Libmount_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "9c30530bf0effd46e15e0fdcf2b8636e78cbbd73"
uuid = "4b2f31a3-9ecc-558c-b454-b3730dcb73e9"
version = "2.35.0+0"

[[Libtiff_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "LERC_jll", "Libdl", "Pkg", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "c9551dd26e31ab17b86cbd00c2ede019c08758eb"
uuid = "89763e89-9b03-5906-acba-b20f662cd828"
version = "4.3.0+1"

[[Libuuid_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "7f3efec06033682db852f8b3bc3c1d2b0a0ab066"
uuid = "38a345b3-de98-5d2b-a5d3-14cd9215e700"
version = "2.36.0+0"

[[LinearAlgebra]]
deps = ["Libdl"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[LogExpFunctions]]
deps = ["ChainRulesCore", "ChangesOfVariables", "DocStringExtensions", "InverseFunctions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "be9eef9f9d78cecb6f262f3c10da151a6c5ab827"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.5"

[[Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "3d3e902b31198a27340d0bf00d6ac452866021cf"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.9"

[[Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[MathOptInterface]]
deps = ["BenchmarkTools", "CodecBzip2", "CodecZlib", "JSON", "LinearAlgebra", "MutableArithmetics", "OrderedCollections", "Printf", "SparseArrays", "Test", "Unicode"]
git-tree-sha1 = "92b7de61ecb616562fd2501334f729cc9db2a9a6"
uuid = "b8f27783-ece8-5eb3-8dc8-9495eed66fee"
version = "0.10.6"

[[MbedTLS]]
deps = ["Dates", "MbedTLS_jll", "Random", "Sockets"]
git-tree-sha1 = "1c38e51c3d08ef2278062ebceade0e46cefc96fe"
uuid = "739be429-bea8-5141-9913-cc70e7f3736d"
version = "1.0.3"

[[MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"

[[Measures]]
git-tree-sha1 = "e498ddeee6f9fdb4551ce855a46f54dbd900245f"
uuid = "442fdcdd-2543-5da2-b0f3-8c86c306513e"
version = "0.3.1"

[[Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "bf210ce90b6c9eed32d25dbcae1ebc565df2687f"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.0.2"

[[Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[Mocking]]
deps = ["Compat", "ExprTools"]
git-tree-sha1 = "29714d0a7a8083bba8427a4fbfb00a540c681ce7"
uuid = "78c3b35d-d492-501b-9361-3d52fe80e533"
version = "0.7.3"

[[MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"

[[MutableArithmetics]]
deps = ["LinearAlgebra", "SparseArrays", "Test"]
git-tree-sha1 = "7bb6853d9afec54019c1397c6eb610b9b9a19525"
uuid = "d8a4904e-b15c-11e9-3269-09a3773c0cb0"
version = "0.3.1"

[[NaNMath]]
git-tree-sha1 = "bfe47e760d60b82b66b61d2d44128b62e3a369fb"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "0.3.5"

[[NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"

[[OffsetArrays]]
deps = ["Adapt"]
git-tree-sha1 = "043017e0bdeff61cfbb7afeb558ab29536bbb5ed"
uuid = "6fe1bfb0-de20-5000-8ca7-80f57d26f881"
version = "1.10.8"

[[Ogg_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "887579a3eb005446d514ab7aeac5d1d027658b8f"
uuid = "e7412a2a-1a6e-54c0-be00-318e2571c051"
version = "1.3.5+1"

[[OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"

[[OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "15003dcb7d8db3c6c857fda14891a539a8f2705a"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "1.1.10+0"

[[OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "13652491f6856acfd2db29360e1bbcd4565d04f1"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.5+0"

[[Opus_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "51a08fb14ec28da2ec7a927c4337e4332c2a4720"
uuid = "91d4177d-7536-5919-b921-800302f37372"
version = "1.3.2+0"

[[OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[PCRE_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b2a7af664e098055a7529ad1a900ded962bca488"
uuid = "2f80f16e-611a-54ab-bc61-aa92de5b98fc"
version = "8.44.0+0"

[[Parsers]]
deps = ["Dates"]
git-tree-sha1 = "ae4bbcadb2906ccc085cf52ac286dc1377dceccc"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.1.2"

[[Pixman_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b4f5d02549a10e20780a24fce72bea96b6329e29"
uuid = "30392449-352a-5448-841d-b1acce4e97dc"
version = "0.40.1+0"

[[Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"

[[PlotThemes]]
deps = ["PlotUtils", "Requires", "Statistics"]
git-tree-sha1 = "a3a964ce9dc7898193536002a6dd892b1b5a6f1d"
uuid = "ccf2f8ad-2431-5c83-bf29-c5338b663b6a"
version = "2.0.1"

[[PlotUtils]]
deps = ["ColorSchemes", "Colors", "Dates", "Printf", "Random", "Reexport", "Statistics"]
git-tree-sha1 = "e4fe0b50af3130ddd25e793b471cb43d5279e3e6"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.1.1"

[[Plots]]
deps = ["Base64", "Contour", "Dates", "Downloads", "FFMPEG", "FixedPointNumbers", "GR", "GeometryBasics", "JSON", "Latexify", "LinearAlgebra", "Measures", "NaNMath", "PlotThemes", "PlotUtils", "Printf", "REPL", "Random", "RecipesBase", "RecipesPipeline", "Reexport", "Requires", "Scratch", "Showoff", "SparseArrays", "Statistics", "StatsBase", "UUIDs", "UnicodeFun"]
git-tree-sha1 = "65ebc27d8c00c84276f14aaf4ff63cbe12016c70"
uuid = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
version = "1.25.2"

[[PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "Dates", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "Markdown", "Random", "Reexport", "UUIDs"]
git-tree-sha1 = "5152abbdab6488d5eec6a01029ca6697dff4ec8f"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.23"

[[Polynomials]]
deps = ["Intervals", "LinearAlgebra", "MutableArithmetics", "RecipesBase"]
git-tree-sha1 = "79bcbb379205f1c62913fa9ebecb413c7a35f8b0"
uuid = "f27b6e38-b328-58d1-80ce-0feddd5e7a45"
version = "2.0.18"

[[PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "db3a23166af8aebf4db5ef87ac5b00d36eb771e2"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.4.0"

[[Preferences]]
deps = ["TOML"]
git-tree-sha1 = "00cfd92944ca9c760982747e9a1d0d5d86ab1e5a"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.2.2"

[[PrettyTables]]
deps = ["Crayons", "Formatting", "Markdown", "Reexport", "Tables"]
git-tree-sha1 = "d940010be611ee9d67064fe559edbb305f8cc0eb"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "1.2.3"

[[Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[Profile]]
deps = ["Printf"]
uuid = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"

[[Qt5Base_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Fontconfig_jll", "Glib_jll", "JLLWrappers", "Libdl", "Libglvnd_jll", "OpenSSL_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libxcb_jll", "Xorg_xcb_util_image_jll", "Xorg_xcb_util_keysyms_jll", "Xorg_xcb_util_renderutil_jll", "Xorg_xcb_util_wm_jll", "Zlib_jll", "xkbcommon_jll"]
git-tree-sha1 = "ad368663a5e20dbb8d6dc2fddeefe4dae0781ae8"
uuid = "ea2cea3b-5b76-57ae-a6ef-0a8af62496e1"
version = "5.15.3+0"

[[REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[Random]]
deps = ["Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[Ratios]]
deps = ["Requires"]
git-tree-sha1 = "01d341f502250e81f6fec0afe662aa861392a3aa"
uuid = "c84ed2f1-dad5-54f0-aa8e-dbefe2724439"
version = "0.4.2"

[[RecipesBase]]
git-tree-sha1 = "6bf3f380ff52ce0832ddd3a2a7b9538ed1bcca7d"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.2.1"

[[RecipesPipeline]]
deps = ["Dates", "NaNMath", "PlotUtils", "RecipesBase"]
git-tree-sha1 = "7ad0dfa8d03b7bcf8c597f59f5292801730c55b8"
uuid = "01d81517-befc-4cb6-b9ec-a95719d0359c"
version = "0.4.1"

[[Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "8f82019e525f4d5c669692772a6f4b0a58b06a6a"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.2.0"

[[SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"

[[Scratch]]
deps = ["Dates"]
git-tree-sha1 = "0b4b7f1393cff97c33891da2a0bf69c6ed241fda"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.1.0"

[[SentinelArrays]]
deps = ["Dates", "Random"]
git-tree-sha1 = "244586bc07462d22aed0113af9c731f2a518c93e"
uuid = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
version = "1.3.10"

[[Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[Showoff]]
deps = ["Dates", "Grisu"]
git-tree-sha1 = "91eddf657aca81df9ae6ceb20b959ae5653ad1de"
uuid = "992d4aef-0814-514b-bc4d-f2e9a6c4116f"
version = "1.0.3"

[[Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "b3363d7460f7d098ca0912c69b082f75625d7508"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.0.1"

[[SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[SpecialFunctions]]
deps = ["ChainRulesCore", "IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "f0bccf98e16759818ffc5d97ac3ebf87eb950150"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "1.8.1"

[[StaticArrays]]
deps = ["LinearAlgebra", "Random", "Statistics"]
git-tree-sha1 = "3c76dde64d03699e074ac02eb2e8ba8254d428da"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.2.13"

[[Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[StatsAPI]]
git-tree-sha1 = "0f2aa8e32d511f758a2ce49208181f7733a0936a"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.1.0"

[[StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "2bb0cb32026a66037360606510fca5984ccc6b75"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.33.13"

[[StructArrays]]
deps = ["Adapt", "DataAPI", "StaticArrays", "Tables"]
git-tree-sha1 = "2ce41e0d042c60ecd131e9fb7154a3bfadbf50d3"
uuid = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
version = "0.6.3"

[[TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"

[[TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "TableTraits", "Test"]
git-tree-sha1 = "bb1064c9a84c52e277f1096cf41434b675cd368b"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.6.1"

[[Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"

[[Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[TimeZones]]
deps = ["Dates", "Downloads", "InlineStrings", "LazyArtifacts", "Mocking", "Printf", "RecipesBase", "Serialization", "Unicode"]
git-tree-sha1 = "ce5aab0b0146b81efefae52f13002e19c2af57ac"
uuid = "f269a46b-ccf7-5d73-abea-4c690281aa53"
version = "1.7.0"

[[TranscodingStreams]]
deps = ["Random", "Test"]
git-tree-sha1 = "216b95ea110b5972db65aa90f88d8d89dcb8851c"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.9.6"

[[UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[UnicodeFun]]
deps = ["REPL"]
git-tree-sha1 = "53915e50200959667e78a92a418594b428dffddf"
uuid = "1cfade01-22cf-5700-b092-accc4b62d6e1"
version = "0.4.1"

[[Wayland_jll]]
deps = ["Artifacts", "Expat_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "3e61f0b86f90dacb0bc0e73a0c5a83f6a8636e23"
uuid = "a2964d1f-97da-50d4-b82a-358c7fce9d89"
version = "1.19.0+0"

[[Wayland_protocols_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "66d72dc6fcc86352f01676e8f0f698562e60510f"
uuid = "2381bf8a-dfd0-557d-9999-79630e7b1b91"
version = "1.23.0+0"

[[WeakRefStrings]]
deps = ["DataAPI", "InlineStrings", "Parsers"]
git-tree-sha1 = "c69f9da3ff2f4f02e811c3323c22e5dfcb584cfa"
uuid = "ea10d353-3f73-51f8-a26c-33c1cb351aa5"
version = "1.4.1"

[[WoodburyMatrices]]
deps = ["LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "de67fa59e33ad156a590055375a30b23c40299d3"
uuid = "efce3f68-66dc-5838-9240-27a6d6f5f9b6"
version = "0.5.5"

[[XML2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "1acf5bdf07aa0907e0a37d3718bb88d4b687b74a"
uuid = "02c8fc9c-b97f-50b9-bbe4-9be30ff0a78a"
version = "2.9.12+0"

[[XSLT_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgcrypt_jll", "Libgpg_error_jll", "Libiconv_jll", "Pkg", "XML2_jll", "Zlib_jll"]
git-tree-sha1 = "91844873c4085240b95e795f692c4cec4d805f8a"
uuid = "aed1982a-8fda-507f-9586-7b0439959a61"
version = "1.1.34+0"

[[Xorg_libX11_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll", "Xorg_xtrans_jll"]
git-tree-sha1 = "5be649d550f3f4b95308bf0183b82e2582876527"
uuid = "4f6342f7-b3d2-589e-9d20-edeb45f2b2bc"
version = "1.6.9+4"

[[Xorg_libXau_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4e490d5c960c314f33885790ed410ff3a94ce67e"
uuid = "0c0b7dd1-d40b-584c-a123-a41640f87eec"
version = "1.0.9+4"

[[Xorg_libXcursor_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXfixes_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "12e0eb3bc634fa2080c1c37fccf56f7c22989afd"
uuid = "935fb764-8cf2-53bf-bb30-45bb1f8bf724"
version = "1.2.0+4"

[[Xorg_libXdmcp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fe47bd2247248125c428978740e18a681372dd4"
uuid = "a3789734-cfe1-5b06-b2d0-1dd0d9d62d05"
version = "1.1.3+4"

[[Xorg_libXext_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "b7c0aa8c376b31e4852b360222848637f481f8c3"
uuid = "1082639a-0dae-5f34-9b06-72781eeb8cb3"
version = "1.3.4+4"

[[Xorg_libXfixes_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "0e0dc7431e7a0587559f9294aeec269471c991a4"
uuid = "d091e8ba-531a-589c-9de9-94069b037ed8"
version = "5.0.3+4"

[[Xorg_libXi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXfixes_jll"]
git-tree-sha1 = "89b52bc2160aadc84d707093930ef0bffa641246"
uuid = "a51aa0fd-4e3c-5386-b890-e753decda492"
version = "1.7.10+4"

[[Xorg_libXinerama_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll"]
git-tree-sha1 = "26be8b1c342929259317d8b9f7b53bf2bb73b123"
uuid = "d1454406-59df-5ea1-beac-c340f2130bc3"
version = "1.1.4+4"

[[Xorg_libXrandr_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "34cea83cb726fb58f325887bf0612c6b3fb17631"
uuid = "ec84b674-ba8e-5d96-8ba1-2a689ba10484"
version = "1.5.2+4"

[[Xorg_libXrender_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "19560f30fd49f4d4efbe7002a1037f8c43d43b96"
uuid = "ea2f1a96-1ddc-540d-b46f-429655e07cfa"
version = "0.9.10+4"

[[Xorg_libpthread_stubs_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "6783737e45d3c59a4a4c4091f5f88cdcf0908cbb"
uuid = "14d82f49-176c-5ed1-bb49-ad3f5cbd8c74"
version = "0.1.0+3"

[[Xorg_libxcb_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "XSLT_jll", "Xorg_libXau_jll", "Xorg_libXdmcp_jll", "Xorg_libpthread_stubs_jll"]
git-tree-sha1 = "daf17f441228e7a3833846cd048892861cff16d6"
uuid = "c7cfdc94-dc32-55de-ac96-5a1b8d977c5b"
version = "1.13.0+3"

[[Xorg_libxkbfile_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "926af861744212db0eb001d9e40b5d16292080b2"
uuid = "cc61e674-0454-545c-8b26-ed2c68acab7a"
version = "1.1.0+4"

[[Xorg_xcb_util_image_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "0fab0a40349ba1cba2c1da699243396ff8e94b97"
uuid = "12413925-8142-5f55-bb0e-6d7ca50bb09b"
version = "0.4.0+1"

[[Xorg_xcb_util_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll"]
git-tree-sha1 = "e7fd7b2881fa2eaa72717420894d3938177862d1"
uuid = "2def613f-5ad1-5310-b15b-b15d46f528f5"
version = "0.4.0+1"

[[Xorg_xcb_util_keysyms_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "d1151e2c45a544f32441a567d1690e701ec89b00"
uuid = "975044d2-76e6-5fbe-bf08-97ce7c6574c7"
version = "0.4.0+1"

[[Xorg_xcb_util_renderutil_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "dfd7a8f38d4613b6a575253b3174dd991ca6183e"
uuid = "0d47668e-0667-5a69-a72c-f761630bfb7e"
version = "0.3.9+1"

[[Xorg_xcb_util_wm_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "e78d10aab01a4a154142c5006ed44fd9e8e31b67"
uuid = "c22f9ab0-d5fe-5066-847c-f4bb1cd4e361"
version = "0.4.1+1"

[[Xorg_xkbcomp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxkbfile_jll"]
git-tree-sha1 = "4bcbf660f6c2e714f87e960a171b119d06ee163b"
uuid = "35661453-b289-5fab-8a00-3d9160c6a3a4"
version = "1.4.2+4"

[[Xorg_xkeyboard_config_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xkbcomp_jll"]
git-tree-sha1 = "5c8424f8a67c3f2209646d4425f3d415fee5931d"
uuid = "33bec58e-1273-512f-9401-5d533626f822"
version = "2.27.0+4"

[[Xorg_xtrans_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "79c31e7844f6ecf779705fbc12146eb190b7d845"
uuid = "c5fb5394-a638-5e4d-96e5-b29de1b5cf10"
version = "1.4.0+3"

[[Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"

[[Zstd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "cc4bf3fdde8b7e3e9fa0351bdeedba1cf3b7f6e6"
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.0+0"

[[libass_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "5982a94fcba20f02f42ace44b9894ee2b140fe47"
uuid = "0ac62f75-1d6f-5e53-bd7c-93b484bb37c0"
version = "0.15.1+0"

[[libfdk_aac_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "daacc84a041563f965be61859a36e17c4e4fcd55"
uuid = "f638f0a6-7fb0-5443-88ba-1cc74229b280"
version = "2.0.2+0"

[[libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "94d180a6d2b5e55e447e2d27a29ed04fe79eb30c"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.38+0"

[[libvorbis_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Ogg_jll", "Pkg"]
git-tree-sha1 = "b910cb81ef3fe6e78bf6acee440bda86fd6ae00c"
uuid = "f27f6e37-5d2b-51aa-960f-b287f2bc3b7a"
version = "1.3.7+1"

[[nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"

[[p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"

[[x264_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fea590b89e6ec504593146bf8b988b2c00922b2"
uuid = "1270edf5-f2f9-52d2-97e9-ab00b5d0237a"
version = "2021.5.5+0"

[[x265_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "ee567a171cce03570d77ad3a43e90218e38937a9"
uuid = "dfaa095f-4041-5dcd-9319-2fabd8486b76"
version = "3.5.0+0"

[[xkbcommon_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Wayland_jll", "Wayland_protocols_jll", "Xorg_libxcb_jll", "Xorg_xkeyboard_config_jll"]
git-tree-sha1 = "ece2350174195bb31de1a63bea3a41ae1aa593b6"
uuid = "d8fb68d0-12a3-5cfd-a85a-d49703b185fd"
version = "0.9.1+5"
"""

# ╔═╡ Cell order:
# ╟─be6956fa-faee-4096-9289-07eae9e88485
# ╟─bced3105-2ab1-4b85-906a-c6a4648a2859
# ╟─58742522-4231-48e2-8e94-56895d57ff11
# ╟─524f2d22-3c12-11ec-167b-3f9d1bf33745
# ╠═d8e070e6-738f-4f65-a41d-0fdab40892c2
# ╠═99167758-610e-4b4c-9004-b45fc04a73d6
# ╟─b2def32b-2660-4d3b-ae85-b8213c2802b5
# ╟─005ccca7-3597-4d5f-99ba-bd76543e8338
# ╟─6877abb6-9208-4ab5-9c70-464f09f59626
# ╟─8db0ec16-148d-4a46-9b5a-2001aa76571b
# ╟─6373ee2f-8061-40d6-8a47-f42ce011a4b3
# ╟─e81dd923-535e-49a4-a83d-0d015c1eb6fe
# ╟─8cbf5879-ed95-42fa-90e2-277891bf9ce1
# ╟─9dd296b9-e388-47e5-8ed7-cf3fc349d358
# ╟─319b8067-fe92-45ef-ad22-20519c12dab9
# ╟─327ef7b0-3e7f-4983-b92f-00d714ae6f19
# ╟─66fafa7a-8323-4ab3-ba4b-0cd72bda1db0
# ╟─d4a1c81c-5bcf-469e-ae55-3e315a0f42a7
# ╟─acc58a0f-de23-4e2d-a812-50048031280e
# ╟─f07800e0-7272-47c6-97b4-481f8c7c86f8
# ╟─00777e04-787e-47ef-b97f-fa6edf7f4489
# ╟─5a3fc936-5fd9-4ec7-a14b-1da1bcfb1a2c
# ╟─a86da162-959c-4b98-bed1-6f7571ad5403
# ╟─ac69db64-0de4-49d4-8899-2b207d8a1316
# ╟─aaf6e457-ef22-4646-8369-a23a450b697d
# ╠═276f0663-a7ac-422f-92e8-8280868135e4
# ╟─1e8dc2cc-e33b-448b-bd3d-3c7b374c2ff5
# ╟─5d24bc1c-42d5-4d97-91d4-608c951afe48
# ╠═e639533d-12fe-4cd1-a46a-204514e2de26
# ╟─74403e12-59b1-41c2-9b00-a5a377f1619b
# ╟─991c3bb7-8175-4bf3-b6c3-47e8a9652231
# ╟─1882c948-35c0-4bdb-a846-fbc997f48628
# ╟─a10768c2-3f9b-4fba-bc0b-9d327eee3871
# ╟─e786cfd6-f834-44bc-be87-285e1bb95402
# ╟─d5951cfe-f237-4589-89bf-561d72ebf2d8
# ╟─cd9d6650-3a03-49fd-b5bb-05fd2f13c24d
# ╟─2113f032-9c95-4102-9915-538a0771669f
# ╟─6d0a13a7-ad46-4f20-81da-a104ba6bb7da
# ╟─81169506-db07-44ad-bb53-d9b3711cce92
# ╟─f5152b0f-ae56-4a42-9fe2-2e9c0793880a
# ╟─771d8c20-8e34-4560-9f86-f5179e5a3072
# ╟─07173e53-b4ed-4623-be47-19d9acaa4384
# ╟─7c7e78db-5809-41f2-9a52-77c01e3a1de3
# ╟─ffcb6c02-7981-4791-a409-973ec5394539
# ╟─2f1f200e-ee28-47be-b928-3bd5b6f6ee2d
# ╟─63dd5f18-b540-48b7-b02d-e7b950a10d49
# ╟─4c15422e-4158-4b5b-b2ac-db95ea61252e
# ╟─aa061f9e-7dc2-41a6-817a-cfa11d403f6b
# ╟─d8e29358-e6ca-42ca-a6d4-657995bdc7b8
# ╟─d83f7e93-b0ab-41d7-afc6-467dbf12ce84
# ╟─06bf0f8e-696d-47f2-aced-4a0d1d9b5e94
# ╟─038f5ca9-1e65-4be9-84fe-6351acfb8b39
# ╟─6d0c651f-a7f8-4e65-8e11-2a43b761aa74
# ╟─69dd2e8d-d1c0-45ee-8b17-7a23424c05d8
# ╟─71f92a0f-f5f0-4950-adec-188a3d9bf18d
# ╟─faef833a-b9a1-4d2a-97a7-f9653d953fb1
# ╠═253f1853-d8a7-4921-9fd4-e0f8c1e2bb36
# ╟─1a713838-7cb6-4ef1-be4e-5bb7d5733918
# ╟─4b74bc7c-55b9-4608-a5ca-581c1395e6cc
# ╟─d251bc5a-3ab8-48ff-9795-f51d024f69fe
# ╠═ab70c5d2-1c09-4ea7-9635-90955b99e475
# ╟─1cf96b28-f109-4e8f-93b6-c35183024025
# ╠═b7cac7c2-0e4c-44a1-80e3-850ffae32b84
# ╠═2675334e-9b82-47a9-84a0-4cfc134f687c
# ╠═f7517994-e184-4d72-a4be-7290fe71b652
# ╟─444879c7-75fe-49c5-bfa7-c04b46fc9130
# ╟─ab9d57d9-7662-46da-b6e8-256a82a119c0
# ╟─958e9699-6d91-4d78-b1cd-9b25774327ae
# ╠═b911a44b-dbb2-4ff1-94cf-0a28b1bc8478
# ╟─263c3995-a588-478d-b54c-7cf71e46e0d9
# ╠═f180cd51-6792-445a-8576-92eb0ed59ef9
# ╠═484e5619-6c48-445c-867b-cff97018004b
# ╟─98fc97fd-70a7-4f5b-927b-e4070d365330
# ╠═dbc4d95a-8e36-4ef7-b769-d9d5e241456b
# ╟─d5f1e93f-3577-4bde-8cf3-541ed515dc7b
# ╟─aca6ca1d-4ed4-4fff-ac27-c4dbc735de5e
# ╟─a22d3676-546d-483d-b05d-f4d7f300f201
# ╟─2fc1b08c-58e5-4ce1-bef6-b266bdd04b40
# ╟─b9159065-7f65-40a8-88d0-91d4c68310f2
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
