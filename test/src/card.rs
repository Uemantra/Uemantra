use colored::Colorize;

#[derive(Debug, Clone, PartialEq)]
pub enum CardEffect {
    None,
    Taunt,
    DivineShield,
    Charge,
    Battlecry(BattlecryEffect),
    Deathrattle(DeathrattleEffect),
}

#[derive(Debug, Clone, PartialEq)]
pub enum BattlecryEffect {
    DealDamage(u32),       // damage to enemy hero
    HealHero(u32),         // heal your hero
    DrawCard,
    GainArmor(u32),
    BuffMinion(i32, i32),  // +attack, +health to a friendly minion
}

#[derive(Debug, Clone, PartialEq)]
pub enum DeathrattleEffect {
    DealDamage(u32),   // deal damage to all enemies
    SummonToken,       // summon a 1/1
    DrawCard,
}

#[derive(Debug, Clone, PartialEq)]
pub enum CardType {
    Minion,
    Spell(SpellEffect),
}

#[derive(Debug, Clone, PartialEq)]
pub enum SpellEffect {
    DealDamage(u32),
    DealDamageAll(u32),
    HealHero(u32),
    DrawCards(u32),
    GainArmor(u32),
    BuffMinion(i32, i32),
    Silence,
}

#[derive(Debug, Clone)]
pub struct Card {
    pub id: u32,
    pub name: String,
    pub cost: u32,
    pub card_type: CardType,
    pub attack: i32,
    pub health: i32,
    pub max_health: i32,
    pub effects: Vec<CardEffect>,
    pub has_attacked: bool,
    pub divine_shield_active: bool,
    pub is_frozen: bool,
    pub just_played: bool,
}

impl Card {
    pub fn new_minion(id: u32, name: &str, cost: u32, attack: i32, health: i32, effects: Vec<CardEffect>) -> Self {
        let has_charge = effects.contains(&CardEffect::Charge);
        let has_divine = effects.contains(&CardEffect::DivineShield);
        Card {
            id,
            name: name.to_string(),
            cost,
            card_type: CardType::Minion,
            attack,
            health,
            max_health: health,
            effects,
            has_attacked: false,
            divine_shield_active: has_divine,
            is_frozen: false,
            just_played: !has_charge,
        }
    }

    pub fn new_spell(id: u32, name: &str, cost: u32, effect: SpellEffect) -> Self {
        Card {
            id,
            name: name.to_string(),
            cost,
            card_type: CardType::Spell(effect),
            attack: 0,
            health: 0,
            max_health: 0,
            effects: vec![],
            has_attacked: false,
            divine_shield_active: false,
            is_frozen: false,
            just_played: false,
        }
    }

    pub fn has_taunt(&self) -> bool {
        self.effects.contains(&CardEffect::Taunt)
    }

    pub fn is_alive(&self) -> bool {
        self.health > 0
    }

    pub fn take_damage(&mut self, amount: i32) -> i32 {
        if self.divine_shield_active {
            self.divine_shield_active = false;
            return 0;
        }
        self.health -= amount;
        amount
    }

    pub fn heal(&mut self, amount: i32) {
        self.health = (self.health + amount).min(self.max_health);
    }

    pub fn display_hand(&self, index: usize) -> String {
        match &self.card_type {
            CardType::Minion => {
                let tags = self.tag_string();
                format!(
                    "[{}] {} ({} mana) {}/{} {}",
                    index.to_string().yellow(),
                    self.name.cyan().bold(),
                    self.cost.to_string().blue(),
                    self.attack.to_string().red(),
                    self.health.to_string().green(),
                    tags
                )
            }
            CardType::Spell(effect) => {
                format!(
                    "[{}] {} ({} mana) SPELL - {}",
                    index.to_string().yellow(),
                    self.name.magenta().bold(),
                    self.cost.to_string().blue(),
                    spell_description(effect)
                )
            }
        }
    }

    pub fn display_board(&self, index: usize, can_attack: bool) -> String {
        let attack_marker = if can_attack { "*".yellow().to_string() } else { " ".to_string() };
        let taunt = if self.has_taunt() { " [T]".white().to_string() } else { String::new() };
        let divine = if self.divine_shield_active { " [DS]".yellow().to_string() } else { String::new() };
        let frozen = if self.is_frozen { " [F]".cyan().to_string() } else { String::new() };
        format!(
            "{}[{}]{} {}{}{} ({}/{})",
            attack_marker,
            index,
            attack_marker,
            self.name.cyan(),
            taunt,
            divine,
            self.attack.to_string().red(),
            self.health.to_string().green(),
        ) + &frozen
    }

    fn tag_string(&self) -> String {
        let mut tags = vec![];
        if self.has_taunt() { tags.push("Taunt".white().to_string()); }
        if self.divine_shield_active { tags.push("Divine Shield".yellow().to_string()); }
        if self.effects.contains(&CardEffect::Charge) { tags.push("Charge".green().to_string()); }
        for e in &self.effects {
            if let CardEffect::Battlecry(_) = e { tags.push("Battlecry".bold().to_string()); break; }
        }
        for e in &self.effects {
            if let CardEffect::Deathrattle(_) = e { tags.push("Deathrattle".italic().to_string()); break; }
        }
        tags.join(" ")
    }
}

fn spell_description(effect: &SpellEffect) -> String {
    match effect {
        SpellEffect::DealDamage(n) => format!("Deal {} damage to enemy hero", n),
        SpellEffect::DealDamageAll(n) => format!("Deal {} damage to all enemies", n),
        SpellEffect::HealHero(n) => format!("Restore {} health to your hero", n),
        SpellEffect::DrawCards(n) => format!("Draw {} card(s)", n),
        SpellEffect::GainArmor(n) => format!("Gain {} armor", n),
        SpellEffect::BuffMinion(a, h) => format!("Give a minion +{}/+{}", a, h),
        SpellEffect::Silence => "Silence a minion".to_string(),
    }
}
