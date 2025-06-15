-- Проект «Секреты Тёмнолесья»
--Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
-- на покупку внутриигровой валюты «райские лепестки», а также оценить 
-- активность игроков при совершении внутриигровых покупок
--
--Автор: Анастасия
--Дата: 11.12.24
--
-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков
--
-- 1.1. Доля платящих пользователей по всем данным:
SELECT COUNT(id) AS all_users, 
SUM(payer) AS pay_user, 
ROUND(AVG(payer)*100,2) AS percent_pay_user
FROM fantasy.users;
-- all_users|pay_user|percent_pay_user
--  22214	|3929	 |17.69
-- Для всей игры доля платящих игроков = 17,69%
-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT r.race, --раса персонажа
SUM(u.payer) AS pay_user, --количество платящих игроков
COUNT(u.id) AS all_users, --общее количество зарегистрированных игроков 
ROUND(SUM(u.payer)::NUMERIC / COUNT(id)::NUMERIC,4)*100 AS percent_pay_user_race -- доля платящих от общего кова в разрезе расы
FROM fantasy.users AS u
LEFT JOIN fantasy.race AS r ON u.race_id=r.race_id
GROUP BY r.race
ORDER BY pay_user DESC;
--rase    |pay_user|all_users|percent_pay_user_race
--Human	  |1114	   |6328	 |17.60
--Hobbit  |659	   |3648	 |18.06
--Orc	  |636	   |3619     |17.57
--Northman|626	   |3562	 |17.57
--Elf	  |427	   |2501	 |17.07
--Demon	  |238	   |1229	 |19.37
--Angel	  |229	   |1327	 |17.26
-- Наибольшая доля от всех покупающих валюту  у расы Демонов 
-- с показателем в 19,4%, на втором месте раса Хоббитов с 18,1 %.
-- Наименьшую доля за раса Эльфами с показателем 17,1%.  
-- Задача 2. Исследование внутриигровых покупок
--
-- 2.1. Статистические показатели по полю amount:
SELECT COUNT(transaction_id) AS all_purchases, --общее количество покупок;
	SUM(amount) AS sum_amount, --сумма. всех покупок;
	MIN(amount) AS min_amount, --мин и макс стоимость покупки
	MAX(amount) AS max_amount, 
	ROUND(AVG(amount::numeric),2) AS avg_amount, --среднее значение
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS mediana, --медианa 
	ROUND(STDDEV(amount::numeric),2) AS std_amount --стандартное отклонение стоимости
FROM fantasy.events;
--all_purchases |sum_amount|min_amount|max_amount|avg_amount|mediana|std_amount
--1307678	    |686615040 | 0.0	  |486615.1	  525.69	 74.86	 2517.35
-- Судя по данным, бОльшее ко-во покупкок недорогие, значительный разброс данных и правосторонняя асимметрия
-- 2.2: Аномальные нулевые покупки:
WITH tab1 AS (SELECT (SELECT COUNT(amount) AS zero_amount--907
		FROM fantasy.events
		WHERE amount IS NULL OR amount=0), 
		COUNT(transaction_id) AS all_purchases
FROM fantasy.events)
SELECT all_purchases, zero_amount, ROUND((zero_amount::NUMERIC / all_purchases::NUMERIC)*100,2) AS percent_zero_amount
FROM tab1;
--all_purchases|zero_amount| percent_zero_amount
-- 1 307 678      907         0.07
-- Обнаружено всего 907 покупок с нулевой стоимостью.
-- Доля этих покупок от общего числа покупок равна 0,07%.
-- Покупки с нулевой стоимостью незначительны и могут быть вызваны различными причинами, нампимер, акции.
-- Проверяем есть ли закономерности в нулевых покупках 
SELECT *
from  fantasy.events
WHERE amount = 0
limit 100;
-- Есть определенная закономерность, похоже большая часть нулевых покупок - предмет с кодом 6010
-- Проверим
SELECT game_items, item_code,
     COUNT(amount) AS zero_amount, -- ко-во покупок с нулевой стоимостью
    (SELECT COUNT(transaction_id) FROM fantasy.events WHERE amount = 0) AS total_zero_amount, -- общ ко-во с нулевой стоимостью
    (SELECT COUNT(transaction_id) FROM fantasy.events) AS total_amount, -- общее количетсво покупок
    -- % покупок amount = 0 от общего числа покупок
    ROUND(COUNT(amount)::NUMERIC / (SELECT COUNT(transaction_id) FROM fantasy.events)::NUMERIC*100.0, 2) AS zero_amount_percent
from  fantasy.events AS e
JOIN fantasy.items AS i USING(item_code)
WHERE amount = 0
GROUP BY game_items, item_code;
--  game_items     | item_code | zero_amount| total_zero_amount | total_amount | zero_amount_percent |
-- Book of Legends |      6010 |        907 |               907 |      1307678 |                0.07 |
-- Все 907 покупок с нулевой стоимостью это 1 предмет
-- Необходимо уточнить, является ли это акцией или ошибкой
-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
-- стат данные, если понадобиться
WITH tab1 AS (SELECT COUNT(transaction_id) AS all_purchases, --общее количество покупок;
	COALESCE(SUM(amount), 0) AS sum_amount, --сумма. всех покупок;
	MIN(amount) AS min_amount, --мин и максстоимость покупки
	MAX(amount) AS max_amount, 
	ROUND(AVG(amount::numeric),2) AS avg_amount, --среднее значение
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS mediana, --медианa 
	ROUND(STDDEV(amount::numeric),2) AS std_amount --стандартное отклонение стоимости
FROM fantasy.events WHERE amount>0 or is null)
-- основной запрос для задачи
WITH tab2 AS (
   SELECT u.id, u.payer,
        COUNT(e.transaction_id) AS all_purchases,  -- общее ко-во покупок 
        COALESCE(SUM(e.amount), 0) AS total_amount -- суммарная стоимость покупок
    FROM
        fantasy.users AS u
   	LEFT JOIN fantasy.events AS e ON u.id = e.id 
    WHERE		
   	e.amount > 0 OR amount IS NULL
    GROUP by u.id, u.payer
)
SELECT
    payer,
     COUNT(id) AS total_players, -- количество игроков в каждой группе 
    ROUND(AVG(all_purchases), 2) AS avg_purchases_per_player, -- среднее количество покупок на одного игрока
    ROUND(AVG(total_amount)::numeric, 2) AS avg_amount_per_player -- средняя суммарная стоимость покупок на одного игрока
FROM tab2
GROUP BY payer;
-- payer | total_players | avg_purchases_per_player | avg_amount_per_player |
--     0 |         18284 |                    60,55 |              30183.38 |
--     1 |          3929 |                    50,81 |              34503.22 |   
--Платящие игроки в среднем делают меньше покупок на одного игрока, чем неплатящие игроки, 
--но при этом их средняя сумма покупок выше.
-- Неплатящие игроки в среднем делают больше покупок на одного игрока, 
--но их средняя сумма покупок на игрока ниже
-- 2.4: Популярные эпические предметы:
SELECT  e.item_code,
		i.game_items,
COUNT(e.transaction_id) AS all_sale_item, --общее ко-во продаж для предмета (абс)
		--доля продажи предмета от всех продаж (относ. знач.)
ROUND(COUNT(e.transaction_id) / (SELECT COUNT(DISTINCT transaction_id) FROM fantasy.events WHERE amount <>0 OR amount IS NOT NULL)::NUMERIC*100,4) 
AS per_sale_item, 
--доля игроков, купивших хотя бы 1 раз
ROUND(COUNT(DISTINCT id) / (SELECT COUNT(DISTINCT id) FROM fantasy.events WHERE amount <>0 OR amount IS NOT NULL)::NUMERIC*100,4) 
AS per_user_pay 
FROM fantasy.events AS e 
LEFT JOIN fantasy.items AS i ON e.item_code=i.item_code
GROUP BY e.item_code, i.game_items
HAVING COUNT(e.transaction_id) >0 
ORDER BY per_user_pay desc
LIMIT 10;
-- Топ 10 предметов с самым большим процентом покупок
--item-code| game_items         | all_sale_item | per_sale_item | per_user_pay
--6010	   |Book of Legends     |1 005 423      |76.8861	    |88.4144
--6011	   |Bag of Holding	    |   271 875	    |20.7907	    |86.7687
--6012	   |Necklace of Wisdom  |	 13 828	    |1.0574	        |11.7958
--6536	   |Gems of Insight	    |      3833	    |0.2931	        |6.7136
--5964	   |Treasure Map	    |      3084	    |0.2358	        |5.4593
--5411	   |Silver Flask	    |       795	    |0.0608	        |4.5893
--4112	   |Amulet of Protection|	   1078	    |0.0824	        |3.2263
--5541	   |Glowing Pendant	    |       563	    |0.0431	        |2.5665
--5691	   |Strength Elixir	    |       580	    |0.0444       	|2.3998
--5661	   |Ring of Wisdom	    |       379	    |0.0290	        |2.2475
-- Book of Legends и Bag of Holdin Самые популярные предметы. Все остальные имеют небольшой% продаж. 
--Значит остальные предметы, не вошедшие в топ 10 покумают крайне редко. 
--Рекомендовано проанализировать возможные причины, почему предметы не покупают и
-- разработать маркетинговую стратегию по повышению продаж
-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:
-- Для каждой расы посчитаем общее количество зарегистрированных игроков
WITH total_players AS (
	SELECT  u.race_id, r.race,
	    COUNT(u.id) AS total_registered_players -- количество зарегистрированных игроков
	from fantasy.race AS r
	LEFT JOIN fantasy.users AS u ON r.race_id = u.race_id
	GROUP BY u.race_id, r.race
),
-- Для каждой расы посчитаем количество игроков, совершивших покупку, и долю платящих игроков
total_paying_players AS ( 
	SELECT  u.race_id,
	    COUNT(DISTINCT CASE WHEN u.payer = 1 THEN u.id END) AS paying_players, -- ко-во игроков, совершивших покупку
	    -- доля игроков, которые совершили покупку
	    ROUND((COUNT(DISTINCT CASE WHEN u.payer = 1 THEN u.id END) * 100.0) / COUNT(DISTINCT u.id), 1) AS paying_percentage
	FROM  fantasy.events AS e
	LEFT JOIN fantasy.users AS u ON u.id = e.id
	WHERE  amount > 0
	GROUP BY u.race_id	
),
-- Доля платящих игроков, совершивших покупку
percent_events_paying_players AS (
	SELECT u.race_id,
    	    -- количество уникальных платящих игроков, которые совершили покупку
   	     COUNT(DISTINCT e.id) AS events_paying_players,
    	    -- общее количество уникальных игроков
   	     COUNT(DISTINCT u.id) AS total_players,
   	     -- доля платящих игроков, которые совершили покупку
   	     ROUND(CASE WHEN COUNT(DISTINCT u.id) > 0 THEN COUNT(DISTINCT e.id)::numeric / COUNT(DISTINCT u.id)::numeric * 100.0 ELSE 0 END, 2) AS percent_paying_players
	FROM  fantasy.users AS u
    LEFT JOIN fantasy.events AS e ON u.id = e.id AND e.amount > 0
	GROUP BY u.race_id	
),
-- Активность игроков с учётом расы персонажа
avg_analitic AS (
        SELECT u.race_id,
            --среднее количество покупок на одного игрока
            COUNT(e.transaction_id) / COUNT(DISTINCT u.id) AS avg_purchases_per_player,	
             --средняя стоимость одной покупки на одного игрока
            ROUND(AVG(e.amount)::numeric, 2) AS avg_amount, 
            --средняя суммарная стоимость всех покупок на одного игрока
            ROUND(SUM(e.amount)::numeric / COUNT(DISTINCT u.id)::numeric, 2) AS avg_amount_per_player
	   FROM  fantasy.events AS e
       LEFT JOIN fantasy.users AS u ON u.id = e.id
	WHERE  e.amount > 0
	GROUP BY  u.race_id
)	
SELECT tp.race_id, tp.race,
    -- количество зарегистрированных игроков
    total_registered_players as "количество зарег-х",
    -- количество игроков, которые совершили покупку
    paying_players as "совершили покупку",
    -- доля игроков, которые совершили покупку
    paying_percentage as "доля соверш.покупку",
    -- доля платящих игроков от количества игроков, которые совершили покупки
    percent_paying_players as "доля платящих от ко-ва совер. покупки",
    -- среднее количество покупок на одного игрока
    avg_purchases_per_player as "ср ко-во покупок на 1 игрока",
    -- средняя стоимость одной покупки на одного игрока
    avg_amount as "ср стоимость 1 покупки на 1 игрока",
    -- средняя суммарная стоимость всех покупок на одного игрока
    avg_amount_per_player as "сред суммарная стоимость всех покупок на 1 игрока"
FROM total_players AS tp
LEFT JOIN total_paying_players AS tpp ON tp.race_id = tpp.race_id
LEFT JOIN percent_events_paying_players AS pepp ON tpp.race_id = pepp.race_id
LEFT JOIN avg_analitic AS aa ON pepp.race_id = aa.race_id
ORDER BY  percent_paying_players DESC;
-- race_id|  race  |"количество зарег-х"|"совершили покупку"|"доля соверш.покупку"|доля платящих от ко-ва совер.покупки|ср ко-во покупок на 1 игрока|ср стоимость 1 покупки на 1 игрокаt|сред суммарная стоимость всех покупок на 1 игрока|
-- K3     |Orc     |3619                |396                |17.4                 |62.89                               |81                          |510.9                              |41761.03
-- C5     |Northman|3562                |406                |18.2                 |62.58                               |82                          |761.5                              |62518.17
-- K4     |Hobbit  |3648                |401                |17.7                 |62.12                               |86                          |552.90                             |47621.80
-- R2     |Human   |6328                |706                |18                   |61.96                               |121                         |403.13                             |48935.22
-- I6     |Angel   |1327                |137                |16.7                 |61.79                               |106                         |455.68                             |48665.73
-- B1     |Elf     |2501                |251                |16.3                 |61.7                                |78                          |682.33                             |53761.70
-- T7     |Demon   |1229                |147                |19.9                 |59.97                               |77                          |529.06                             |41194.84
---
-- Раса "Orc" имеет самую высокую долю платящих игроков (62,89) и среднее количество покупок на одного игрока равно 81.
-- Расы  Demon и Angel имеют наименьшнй ко-во игроков совершивших покупку 147 и 137 соответственно, и доли платящих от ко-ва совершивших покупку 59.97  % и 61.79   соответственно.
-- Возможно эти расы не нуждаются в покупках так же, как остальные, но нельзя сделать однозначный вывод,
-- что прохождение игры за персонажей разных рас требует примерно равного количества покупок
-- Задача 2: Частота покупок
-- Ко-во дней между покупками для каждого игрока при amount > 0
with tab1 AS (
    SELECT id, date,  amount,
    		date::timestamp - LAG(date, 1, date) OVER (PARTITION BY id ORDER BY date)::timestamp AS days_since_last_purchase --дни между покупками
    FROM fantasy.events
    WHERE amount > 0
),
-- Для каждого игрока подсчитываем общее количество покупок и среднее количество дней между покупками
 	tab2 AS (
    SELECT id,
        COUNT(*) AS total_purchases,
        AVG(days_since_last_purchase) AS avg_days_between_purchases,
        (SELECT payer FROM fantasy.users WHERE fantasy.users.id = tab1.id) as payer
    FROM tab1
    GROUP BY id
),
-- Разделяем игроков на три группы по среднему количеству дней между покупками
   tab3 AS (
    SELECT  id, total_purchases, avg_days_between_purchases, payer,
        NTILE(3) OVER (ORDER BY avg_days_between_purchases) AS frequency_group
    FROM tab2
    	tab2
    WHERE	total_purchases >= 25
),
-- Для каждой группы рассчитывает необходимые метрики
		tab4 AS (
    SELECT   frequency_group,
        -- общее количество игроков
        COUNT(id) AS total_players,
        -- количество платящих игроков
        COUNT(CASE WHEN payer = 1 THEN id END) AS paying_players,
        -- среднее количество покупок
        ROUND(AVG(total_purchases), 2) AS avg_purchases_per_player,
        -- среднее количество дней между покупками
        AVG(avg_days_between_purchases) AS avg_days_between_purchases_per_player
    FROM  tab3
    GROUP BY  	frequency_group
)
SELECT
    CASE frequency_group
        WHEN 1 THEN 'высокая частота'
        WHEN 2 THEN 'средняя частота'
        WHEN 3 THEN 'низкая частота'
    END AS frequency_group,
    total_players,
    paying_players,
    -- % платящих игроков
    ROUND(CAST(paying_players AS REAL)::numeric * 100 / total_players, 2) AS paying_players_percentage,
    avg_purchases_per_player,
    avg_days_between_purchases_per_player
FROM
    tab4;
-- frequency_group  |total_players|paying_players|paying_players_percentage|avg_purchases_per_player|avg_days_between_purchases_per_player
-- высокая частота  |        2572 |          471 |                   18.31 |                 390.60 |              2 days 
-- средняя частотам |        2572 |          451 |                   17.53 |                  58.85 |              6 days 
-- низкая частота   |        2572 |          435 |                   16.91 |                  33.65 |             12 days 
-- Высокая частота -  среднем, каждый игрок из этой группы совершает 390 покупок раз в 2 дня
-- Средняя частота - среднем, каждый игрок из этой группы совершает 58 покупок раз в 6 дней
-- Низкая частота. - среднем, каждый игрок из этой группы совершает 33 покупки раз в 12 дней
--
-- Общие выводы и рекомендации:
-- 	1. Развивать монетизацию игры, разработать маркетинговую стратегию для каждой рассы, внедрить персональные предложения
-- Особое внимание на расы ангелов и демонов, демонстрирующих наименьшее ко-во покупок. Есть предположение о дисбалансе между расами, который влияет на необходимость покупки
-- 	2. Изучить поведение игроков с малым количеством покупок -активно стимулировать к покупке, например дополнительные бонусы за покупки предмета, награды за частые покупки
-- 	3. Разработать стратегии привлечения новых платящих игроков и удержания текущих.
-- 	4. Пересмотреть характеристики менее продаваемых предметов
--  5. Внимание на бесплатный предмет акция или ошибка?