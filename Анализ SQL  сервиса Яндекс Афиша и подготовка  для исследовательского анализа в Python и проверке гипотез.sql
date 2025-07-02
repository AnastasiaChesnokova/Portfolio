-- Анализ данных  SQL  сервиса Яндекс Афишаи подготовка  для исследовательского анализа в Python и проверке гипотез 
-- Близится период распродаж и новогодних акций.
-- Нужна детальная аналитика и убедительные инсайты. 
-- Пока не понятно, почему продажи билетов на одни мероприятия неожиданно растут, а на другие — снижаются.
-- Необходимо узнать, какие события стали привлекать больше зрителей, а какие организаторы и площадки выбились в лидеры.
-- А также выяснить, отличаются ли своей активностью пользователи мобильных устройств от клиентов, которые бронируют билеты со стационарного компьютера.
--
--Запросы для знакомства с данными (не все)
--По типам мероприятий
SELECT event_type_description, COUNT(*) AS count_orders
FROM events
JOIN purchases ON events.event_id = purchases.event_id
GROUP BY event_type_description
ORDER BY count_orders DESC;
--По устройствам:
SELECT device_type_canonical, COUNT(*) AS count_orders
FROM purchases
GROUP BY device_type_canonical
ORDER BY count_orders DESC;
--По валютам:
SELECT currency_code, SUM(revenue) AS total_revenue, COUNT(*) AS total_orders
FROM purchases
GROUP BY currency_code;
-- Анализ аномалий и некорректных значений
-- Общая статистика:
SELECT 
    MIN(revenue) AS min_revenue,
    MAX(revenue) AS max_revenue,
    AVG(revenue) AS avg_revenue,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY revenue) AS q1,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY revenue) AS q3,
    STDDEV(revenue) AS stddev_revenue
FROM purchases;
--Проверка на отрицательные или нулевые значения выручки:
SELECT COUNT(*) FROM purchases WHERE revenue <= 0;
--Анализ временного периода:
--Определить диапазон дат:
SELECT MIN(created_dt_msk), MAX(created_dt_msk) FROM purchases;
--Построить распределение заказов по времени (например, по месяцам):
SELECT DATE_TRUNC('month', created_dt_msk) AS month, COUNT(*) AS orders_count
FROM purchases
GROUP BY month ORDER BY month;
--
--1. Общие значения ключевых показателей сервиса за весь период:
SELECT
    currency_code, --алюта
    SUM(revenue) AS total_revenue, --сумма выручки
    COUNT(DISTINCT order_id) AS total_orders, --ко-во уникальных заказов
    ROUND(AVG(revenue::numeric),2) AS avg_revenue_per_order, -- ср стоимость заказа
    COUNT(DISTINCT user_id)total_users -- ко-во уникальных пользователей
FROM afisha.purchases
GROUP BY currency_code
ORDER BY total_revenue DESC;
--currency_code|total_revenue|total_orders|avg_revenue_per_order|total_users
--rub	       | 157127696	 |   286961	  |547.57               |21422
--kzt	       | 25341034	 |   5073	  |4995.31           	|1362
--
-- Заказов билетов в тенге намного меньше, чем рублях.
--2. Изучение распределения выручки в разрезе устройств
SELECT 
    device_type_canonical,--тип устройства
    SUM(revenue) AS total_revenue, --общая выручка с заказов
    COUNT(DISTINCT order_id) AS total_orders, --количество заказов
    ROUND(AVG(revenue::numeric), 2) AS avg_revenue_per_order, --средняя стоимость заказа
    ROUND(SUM(revenue::numeric) / total_revenue_total, 3) AS revenue_share --доля выручки для каждого устройства от общего значения
FROM (
    SELECT 
        p.*,
        (SELECT SUM(revenue::numeric) FROM afisha.purchases WHERE currency_code = 'rub') AS total_revenue_total
    FROM afisha.purchases p
    WHERE p.currency_code = 'rub'
) sub
GROUP BY device_type_canonical, total_revenue_total
ORDER BY revenue_share DESC;
--device..|total_revenue|total_orders|avg_revenue_per_order|revenue_share
--mobile  | 124632400	|229021	     |544.20	           |0.793
--desktop |	31851708	|56759	     |561.17	           |0.203
--tablet  |	640987.94	|1176	     |545.06	           |0.004
--other	  |  5133.7603	|2	         |2566.88	           |0.000
--tv	  |  1299.16	|3	         |433.05	           |0.000
--Основная часть выручки приходится на мобильные устройства и стационарные компьютеры. 
--Доля остальных устройств в структуре выручки минимальна и составляет меньше процента.
--3. Изучение распределения выручки в разрезе типа мероприятий для заказов в рублях 
--
SELECT
    e.event_type_main AS event_type, --тип мероприятия
    SUM(p.revenue) AS total_revenue, -- общая выручка с заказов 
    COUNT(p.order_id) AS total_orders, -- количество заказов 
    AVG(p.revenue) AS avg_revenue_per_order, --средняя стоимость заказа
    COUNT(DISTINCT e.event_name_code) AS total_event_name, -- уникальное число событий
    AVG(p.tickets_count) AS avg_tickets, -- среднее число билетов в заказе 
    (SUM(p.revenue) / NULLIF(SUM(p.tickets_count), 0)) AS avg_ticket_revenue, --средняя выручка с одного билета 
    ROUND(
        (SUM(p.revenue)::numeric / (
            SELECT SUM(revenue)::numeric
            FROM afisha.purchases
            WHERE currency_code = 'rub'
        ))::numeric,
        3
    ) AS revenue_share --доля выручки от общего значения 
FROM
    afisha.purchases p
JOIN
    afisha.events e ON p.event_id = e.event_id
WHERE
    p.currency_code = 'rub'
    AND p.tickets_count > 0
GROUP BY
    e.event_type_main
ORDER BY
    total_orders DESC;
-- event_type |	total_revenue	|total_orders|	avg_revenue_per_order|	total_event_name|	avg_tickets     |avg_ticket_revenue |revenue_share
--концерты	  |88705888	        |112418    	 |789.0850212149544	     |6014	            |2.6570389083598712	|296.9741713229706	|0.565
--театр	      |37141508	        |67733	     |548.3568227249012	     |4352	            |2.7600726381527468	|198.67293578963134	|0.236
--другое	  |15579770	        |64572	     |241.28204110350754	 |3807	            |2.7648361518924611	|87.26646912861072	|0.099
--спорт	      |3466692.5        |21700	     |159.75414450427698	 |785	            |3.0534101382488479	|52.320326295295736	|0.022
--стендап	  |9547284.0	    |13421	     |711.3644202233036	     |420	            |2.9919529096192534	|237.76077698916697	|0.061
--выставки	  | 1135891.2       |4873	     |233.10002582614584	 |279	            |2.5581777139339216	|91.1191440718755	|0.007
--ёлки	      |1549356.2        |2006	     |772.3603511403351	     |173	            |3.3424725822532403	|231.0747576435496	|0.010
--фильм	      |3084.8103        |238	     |12.961386680603027	 |19	            |2.6554621848739496	|4.8810289600227454	|0.000
--
--Концерты лидируют по выручке (88,7 млн руб.) и количеству заказов (112 418), что говорит о высокой популярности и масштабности этого сегмента.
--Театры занимают второе место по выручке (37,1 млн руб.) и количеству заказов (67 733), показывая стабильный спрос.
--Самая высокая средняя выручка за заказ у стендапа (около 711 руб.), что может свидетельствовать о более дорогих билетах или более платёжеспособной аудитории.
--Наименьшая — у фильмов (около 13 руб.), что говорит о низкой стоимости билетов или меньшей ценовой политики.
--В целом, среднее число билетов в заказе невысокое (около 2-3 билета), что характерно для большинства сегментов.
-- Самая высокая — у стендапа (~238 руб.), что подтверждает более дорогие билеты.
-- Наименьшая — у фильмов (~4.88 руб.), что может быть связано с низкими ценами или скидками.
--По доле выручки:
--Наиболее значимый сегмент — концерты, с долей около 56.5%, что говорит о их доминирующей роли в общем рынке.
-- Следом идут театры (~23.6%) и остальные сегменты занимают значительно меньшую часть.
--Общая картина:
--Концерты являются ключевым драйвером рынка по выручке и популярности.
--В сегментах типа кино или выставок наблюдается низкая выручка и меньшая активность,
-- что может свидетельствовать о нишевом положении или необходимости развития данных направлений.
--Высокий средний чек у стендапа и концертов говорит о возможности увеличения дохода за счет повышения цен или расширения премиальных предложений.
--3. Динамика изменения значений для заказов в рублях 
--изменение выручки, количества заказов, уникальных клиентов и средней стоимости одного заказа в недельной динамике: 
   SELECT 
    DATE_TRUNC('week',  created_dt_msk)::date AS week, 
    SUM(revenue) AS total_revenue,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT user_id) AS total_users,
    (SUM(revenue) / NULLIF(COUNT(order_id), 0)) AS revenue_per_order --ср стоимость заказа
FROM afisha.purchases
WHERE currency_code = 'rub'
GROUP BY DATE_TRUNC('week', created_dt_msk)
ORDER BY week;
-- week     |t. revenue   |t. orders|t. users|revenue_per_order
--2024-05-27	911625.9	2024	805	    450.4080410079051
--2024-06-03	3989500.5	7589    2238	525.6951508762683
--2024-06-10	4160547.8	7431	2153	559.890694388373
--2024-06-17	4612199.0	8043	2143	573.4426209125947
--2024-06-24	4243705.5	7362	2032	576.4337815810921
--2024-07-01	5159806.0	8995	2296	573.6304613674264
--2024-07-08	5511003.0	8980	2310	613.6974387527839
--2024-07-15	5580827.0	8836	2406	631.6010638297872
--2024-07-22	5457100.5	9347	2421	583.8344388573873
--2024-07-29	5846351.5	10536	2492	554.892891040243
--2024-08-05	6235606.0	9642	2546	646.7129226301597
--2024-08-12	6081589.5	9719	2596	625.7423088795143
--2024-08-19	5823015.0	10488	2654	555.2073798627002
--2024-08-26	5701570.0	10157	2527	561.3439007580979
--2024-09-02	6926391.0	15642	3075	442.807249712313
--2024-09-09	8349255.5	15706	3431	531.5965554565134
--2024-09-16	9044691.0	16599	3509	544.8937285378637
--2024-09-23	9865459.0	17554	3768	562.0063233451066
--2024-09-30	11440944	23031	4071	496.76279796795626
--2024-10-07	10978287	19420	4118	565.3082904222451
--2024-10-14	12096930	22438	4420	539.1269275336483
--2024-10-21	12207004	22810	4475	535.1601928978519
--2024-10-28	6907834.5	14612	3019	472.75078702436355
--Виден рост количества заказов и пользователей к концу временного периода.
-- 4. Выделение топ-регионов по значению общей выручки,только заказы за рубли.
WITH regional_stats AS (
    SELECT
        r.region_name,
        SUM(p.revenue) AS total_revenue,
        COUNT(p.order_id) AS total_orders,
        COUNT(DISTINCT p.user_id) AS total_users,
        SUM(p.tickets_count) AS total_tickets
    FROM afisha.purchases AS  p
    JOIN afisha.events AS e ON p.event_id = e.event_id
    JOIN afisha.city AS c ON e.city_id = c.city_id
    JOIN afisha.regions AS r ON c.region_id = r.region_id
    WHERE p.currency_code = 'rub'
    GROUP BY r.region_name
)
SELECT
    region_name,
    total_revenue,
    total_orders,
    total_orders,
    total_tickets,
    CASE WHEN total_tickets > 0 THEN total_revenue / total_tickets ELSE 0 END AS one_ticket_cost
FROM regional_stats
ORDER BY total_revenue DESC
LIMIT 7;
--region_name          |total_revenue|total_orders|total_orders|total_tickets|one_ticket_cost
--Каменевский регион   |61555620	 |91634	      |10646	   |253393	     |242.92549517942484
--Североярская область |25453278	 |44282	      |6735	       |125204       |203.29444746174244
--Озернинский край	   |9793623.0	 |10502	      |2488	       |29621	     |330.6310725498802
--Широковская область  |9543781.0	 |16538	      |3278	       |46977	     |203.15858824531153
--Малиновоярский округ |5955931.0	 |6634	      |1902	       |17465	     |341.0209561981105
--Яблоневская область  |3692400.0	 |6197	      |1431	       |16589	     |222.58122852492616
--Светополянский округ |3425873.8	 |7632        |1683	       |20434	     |167.65556180875012
--
--
--
--Подготовка данных для исследовательского анализа в Python и проверке гипотез.
-- создание датасета  final_tickets_orders_df.csv
--Включает информацию обо всех заказах билетов, 
--совершённых с двух типов устройств — мобильных и стационарных. 
--Поля датасета соответствуют таблице purchases,
--В данные также был добавлен столбец days_since_prev с количеством дней с предыдущей покупки для каждого пользователя. 
--Если покупки не было, то данные содержат пропуск.
SELECT *,
       created_dt_msk::date - LAG(created_dt_msk) OVER(PARTITION BY user_id ORDER BY created_dt_msk)::date 
AS days_since_prev
FROM afisha.purchases
WHERE -- Фильтруем тип устройства
 device_type_canonical IN ('mobile',
                           'desktop');
--создание датасета final_tickets_orders_df.csv
--содержит информацию о событиях, включая город и регион события,
-- а также информацию о площадке проведения мероприятия. 
--Выручка от заказов может бы представлена в разных валютах. 
data — дата;
curs — курс тенге к рублю;
cdx — обозначение валюты (kzt).
                          SELECT -- Выгружаем данные таблицы events:
 e.event_id,
 e.event_name_code AS event_name,
 e.event_type_description,
 e.event_type_main,
 e.organizers, 
 -- Выгружаем информацию о городе и регионе:
 r.region_name,
 c.city_name,
 c.city_id, 
 -- Выгружаем информацию о площадке:
 v.venue_id,
 v.venue_name,
 v.address AS venue_address
FROM afisha.events AS e
LEFT JOIN afisha.venues AS v USING(venue_id)
LEFT JOIN afisha.city AS c USING(city_id)
LEFT JOIN afisha.regions AS r USING(region_id)
WHERE e.event_id IN
    (SELECT DISTINCT event_id
     FROM afisha.purchases
     WHERE -- Фильтруем тип устройства
 device_type_canonical IN ('mobile',
                           'desktop'))
  AND e.event_type_main != 'фильм'; 
  