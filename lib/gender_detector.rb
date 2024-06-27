class GenderDetector
  def initialize
    @russian_male_names = %w[
      Александр Алексей Анатолий Андрей Антон Аркадий Арсений Артем Артур
      Борис Вадим Валентин Валерий Василий Виктор Виталий Владимир Владислав
      Геннадий Георгий Глеб Григорий Даниил Денис Дмитрий Евгений Егор
      Иван Игорь Илья Кирилл Константин Лев Леонид Максим Марк Михаил
      Никита Николай Олег Павел Петр Роман Руслан Сергей Станислав
      Степан Тимофей Федор Юрий Ярослав
    ]

    @russian_female_names = %w[
      Александра Алена Алина Алиса Алла Анастасия Анна Арина
      Валентина Валерия Вера Вероника Виктория Галина Дарья Диана
      Евгения Екатерина Елена Елизавета Жанна Зоя Инна Ирина
      Карина Кира Клавдия Кристина Ксения Лариса Лидия Любовь
      Людмила Маргарита Марина Мария Надежда Наталья Нина Оксана
      Ольга Полина Раиса Светлана София Софья Тамара Татьяна
      Ульяна Юлия Яна
    ]

    @english_male_names = %w[
      Adam Alexander Andrew Anthony Arthur
      Benjamin Brian Charles Christopher Daniel
      David Edward Eric George Harry
      Henry Jack James John Kevin
      Mark Matthew Michael Patrick Paul
      Peter Richard Robert Steven Thomas
      William
    ]

    @english_female_names = %w[
      Alice Amanda Amy Anna Ashley
      Barbara Betty Carol Catherine Charlotte
      Elizabeth Emily Emma Grace Hannah
      Helen Jennifer Jessica Julia Karen
      Katherine Kimberly Laura Linda Lisa
      Margaret Mary Michelle Nancy Olivia
      Patricia Rachel Rebecca Sarah Susan
      Victoria
    ]

    @male_names = {}
    @female_names = {}

    (@russian_male_names + @english_male_names).each do |name|
      @male_names[name.downcase] = true

      @male_names[transliterate_to_latin(name).downcase] = true if cyrillic?(name)
      @male_names[transliterate_to_cyrillic(name).downcase] = true if latin?(name)
    end

    (@russian_female_names + @english_female_names).each do |name|
      @female_names[name.downcase] = true

      @female_names[transliterate_to_latin(name).downcase] = true if cyrillic?(name)
      @female_names[transliterate_to_cyrillic(name).downcase] = true if latin?(name)
    end

    @male_indicators = %w[boy guy man mr mister male]
    @female_indicators = %w[girl lady woman mrs miss ms female]
  end

  def detect_gender(first_name, last_name, username)
    scores = {male: 0, female: 0}

    first_name = first_name.to_s.strip.downcase

    if @male_names[first_name]
      scores[:male] += 3
    elsif @female_names[first_name]
      scores[:female] += 3
    else
      scores = apply_russian_name_rules(first_name, scores)
    end

    last_name = last_name.to_s.strip.downcase
    if last_name.length > 2
      scores[:female] += 1 if last_name.end_with?('ва', 'на', 'ая')

      scores[:male] += 1 if last_name.end_with?('ов', 'ев', 'ин', 'ий', 'ый', 'ой')

      if last_name.end_with?('ов') && @male_names[first_name]
        scores[:male] += 1
      elsif last_name.end_with?('ова') && @female_names[first_name]
        scores[:female] += 1
      end
    end

    username = username.to_s.strip.downcase

    @male_indicators.each do |indicator|
      scores[:male] += 1 if username.include?(indicator)
    end

    @female_indicators.each do |indicator|
      scores[:female] += 1 if username.include?(indicator)
    end

    if scores[:male] > scores[:female]
      'male'
    elsif scores[:female] > scores[:male]
      'female'
    else
      'unknown'
    end
  end

  private

  def apply_russian_name_rules(name, scores)
    if name.end_with?('а', 'я')
      scores[:female] += 2
    elsif name.end_with?(*%w[б в г д ж з к л м н п р с т ф х ц ч ш щ й])
      scores[:male] += 2
    end

    scores[:female] += 1 if name.end_with?('ечка', 'енька', 'онька', 'ушка')
    scores[:male] += 1 if name.end_with?('ик', 'ок', 'ек')

    scores
  end

  def cyrillic?(text)
    text.match?(/[А-Яа-я]/)
  end

  def latin?(text)
    text.match?(/[A-Za-z]/)
  end

  def transliterate_to_latin(text)
    mapping = {
      'а' => 'a', 'б' => 'b', 'в' => 'v', 'г' => 'g', 'д' => 'd', 'е' => 'e', 'ё' => 'yo',
      'ж' => 'zh', 'з' => 'z', 'и' => 'i', 'й' => 'y', 'к' => 'k', 'л' => 'l', 'м' => 'm',
      'н' => 'n', 'о' => 'o', 'п' => 'p', 'р' => 'r', 'с' => 's', 'т' => 't', 'у' => 'u',
      'ф' => 'f', 'х' => 'kh', 'ц' => 'ts', 'ч' => 'ch', 'ш' => 'sh', 'щ' => 'sch',
      'ъ' => '', 'ы' => 'y', 'ь' => '', 'э' => 'e', 'ю' => 'yu', 'я' => 'ya',

      'А' => 'A', 'Б' => 'B', 'В' => 'V', 'Г' => 'G', 'Д' => 'D', 'Е' => 'E', 'Ё' => 'Yo',
      'Ж' => 'Zh', 'З' => 'Z', 'И' => 'I', 'Й' => 'Y', 'К' => 'K', 'Л' => 'L', 'М' => 'M',
      'Н' => 'N', 'О' => 'O', 'П' => 'P', 'Р' => 'R', 'С' => 'S', 'Т' => 'T', 'У' => 'U',
      'Ф' => 'F', 'Х' => 'Kh', 'Ц' => 'Ts', 'Ч' => 'Ch', 'Ш' => 'Sh', 'Щ' => 'Sch',
      'Ъ' => '', 'Ы' => 'Y', 'Ь' => '', 'Э' => 'E', 'Ю' => 'Yu', 'Я' => 'Ya'
    }

    result = ""
    text.each_char do |char|
      result += mapping[char] || char
    end

    result
  end

  def transliterate_to_cyrillic(text)
    text.gsub(/([A-Za-z]+)/) do |word|
      word.gsub(/sh|zh|ch|sch|yu|ya|yo|[a-z]/i) do |match|
        case match.downcase
        when 'a' then 'а'
        when 'b' then 'б'
        when 'v' then 'в'
        when 'g' then 'г'
        when 'd' then 'д'
        when 'e' then 'е'
        when 'yo' then 'ё'
        when 'zh' then 'ж'
        when 'z' then 'з'
        when 'i' then 'и'
        when 'y' then 'й'
        when 'k' then 'к'
        when 'l' then 'л'
        when 'm' then 'м'
        when 'n' then 'н'
        when 'o' then 'о'
        when 'p' then 'п'
        when 'r' then 'р'
        when 's' then 'с'
        when 't' then 'т'
        when 'u' then 'у'
        when 'f' then 'ф'
        when 'kh' then 'х'
        when 'ts' then 'ц'
        when 'ch' then 'ч'
        when 'sh' then 'ш'
        when 'sch' then 'щ'
        when 'yu' then 'ю'
        when 'ya' then 'я'
        else match
        end
      end
    end
  end
end
