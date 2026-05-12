use crate::card::{Card, CardType};
use colored::Colorize;

pub struct Player {
    pub name: String,
    pub hp: i32,
    pub max_hp: i32,
    pub armor: i32,
    pub mana: u32,
    pub max_mana: u32,
    pub hand: Vec<Card>,
    pub deck: Vec<Card>,
    pub board: Vec<Card>,
    pub is_ai: bool,
}

impl Player {
    pub fn new(name: &str, deck: Vec<Card>, is_ai: bool) -> Self {
        Player {
            name: name.to_string(),
            hp: 30,
            max_hp: 30,
            armor: 0,
            mana: 0,
            max_mana: 0,
            hand: vec![],
            deck,
            board: vec![],
            is_ai,
        }
    }

    pub fn draw(&mut self, n: u32) -> Vec<String> {
        let mut msgs = vec![];
        for _ in 0..n {
            if self.hand.len() >= 10 {
                msgs.push(format!("{}'s hand is full! Card burned.", self.name));
                self.deck.pop();
            } else if let Some(card) = self.deck.pop() {
                msgs.push(format!("{} drew {}.", self.name, card.name));
                self.hand.push(card);
            } else {
                self.take_damage(3);
                msgs.push(format!("{} has no cards! Took 3 fatigue damage.", self.name));
            }
        }
        msgs
    }

    pub fn start_turn(&mut self) {
        if self.max_mana < 10 {
            self.max_mana += 1;
        }
        self.mana = self.max_mana;
        for minion in &mut self.board {
            minion.has_attacked = false;
            minion.just_played = false;
            if minion.is_frozen {
                minion.is_frozen = false;
            }
        }
    }

    pub fn take_damage(&mut self, amount: i32) -> i32 {
        let absorbed = self.armor.min(amount);
        self.armor -= absorbed;
        let remaining = amount - absorbed;
        self.hp -= remaining;
        amount
    }

    pub fn heal(&mut self, amount: i32) {
        self.hp = (self.hp + amount).min(self.max_hp);
    }

    pub fn is_dead(&self) -> bool {
        self.hp <= 0
    }

    pub fn can_attack_with(&self, index: usize) -> bool {
        if let Some(m) = self.board.get(index) {
            !m.has_attacked && !m.just_played && !m.is_frozen && m.attack > 0
        } else {
            false
        }
    }

    pub fn display_board_minions(&self, show_attack_markers: bool) -> String {
        if self.board.is_empty() {
            return "  (empty board)".dimmed().to_string();
        }
        self.board
            .iter()
            .enumerate()
            .map(|(i, m)| {
                let can = show_attack_markers && self.can_attack_with(i);
                format!("  {}", m.display_board(i, can))
            })
            .collect::<Vec<_>>()
            .join("\n")
    }

    pub fn display_status(&self) -> String {
        let hp_str = format!("HP: {}/{}", self.hp, self.max_hp);
        let armor_str = if self.armor > 0 { format!(" (+{} armor)", self.armor) } else { String::new() };
        let mana_str = format!("Mana: {}/{}", self.mana, self.max_mana);
        let deck_str = format!("Deck: {} cards", self.deck.len());
        let hand_str = format!("Hand: {} cards", self.hand.len());
        format!(
            "{} | {} {}{} | {} | {}",
            self.name.bold(),
            hp_str.green(),
            armor_str.cyan(),
            "",
            mana_str.blue(),
            deck_str.dimmed(),
        ) + " | " + &hand_str.dimmed()
    }

    pub fn has_minion_with_taunt(&self) -> bool {
        self.board.iter().any(|m| m.has_taunt())
    }

    pub fn is_minion(&self, index: usize) -> bool {
        matches!(self.board.get(index).map(|c| &c.card_type), Some(CardType::Minion))
    }
}
