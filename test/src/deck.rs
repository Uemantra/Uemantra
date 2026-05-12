use crate::card::{Card, CardEffect, BattlecryEffect, DeathrattleEffect, SpellEffect};
use rand::seq::SliceRandom;
use rand::thread_rng;

static mut NEXT_ID: u32 = 1;

fn next_id() -> u32 {
    unsafe {
        let id = NEXT_ID;
        NEXT_ID += 1;
        id
    }
}

pub fn all_cards() -> Vec<Card> {
    vec![
        // 1-cost minions
        Card::new_minion(next_id(), "Wisp", 0, 1, 1, vec![]),
        Card::new_minion(next_id(), "Stonetusk Boar", 1, 1, 1, vec![CardEffect::Charge]),
        Card::new_minion(next_id(), "Northshire Cleric", 1, 1, 3, vec![CardEffect::Battlecry(BattlecryEffect::DrawCard)]),
        Card::new_minion(next_id(), "Shield Bearer", 1, 0, 4, vec![CardEffect::Taunt]),

        // 2-cost minions
        Card::new_minion(next_id(), "River Crocolisk", 2, 2, 3, vec![]),
        Card::new_minion(next_id(), "Bloodfen Raptor", 2, 3, 2, vec![]),
        Card::new_minion(next_id(), "Loot Hoarder", 2, 2, 1, vec![CardEffect::Deathrattle(DeathrattleEffect::DrawCard)]),
        Card::new_minion(next_id(), "Faerie Dragon", 2, 3, 2, vec![]),
        Card::new_minion(next_id(), "Kobold Geomancer", 2, 2, 2, vec![CardEffect::Battlecry(BattlecryEffect::DealDamage(1))]),

        // 3-cost minions
        Card::new_minion(next_id(), "Ironfur Grizzly", 3, 3, 3, vec![CardEffect::Taunt]),
        Card::new_minion(next_id(), "Shattered Sun Cleric", 3, 3, 2, vec![CardEffect::Battlecry(BattlecryEffect::BuffMinion(1, 1))]),
        Card::new_minion(next_id(), "Raid Leader", 3, 2, 2, vec![]),
        Card::new_minion(next_id(), "Scarlet Crusader", 3, 3, 1, vec![CardEffect::DivineShield]),

        // 4-cost minions
        Card::new_minion(next_id(), "Chillwind Yeti", 4, 4, 5, vec![]),
        Card::new_minion(next_id(), "Gnomish Inventor", 4, 2, 4, vec![CardEffect::Battlecry(BattlecryEffect::DrawCard)]),
        Card::new_minion(next_id(), "Sen'jin Shieldmasta", 4, 3, 5, vec![CardEffect::Taunt]),
        Card::new_minion(next_id(), "Harvest Golem", 4, 2, 3, vec![CardEffect::Deathrattle(DeathrattleEffect::SummonToken)]),

        // 5-cost minions
        Card::new_minion(next_id(), "Darkscale Healer", 5, 4, 5, vec![CardEffect::Battlecry(BattlecryEffect::HealHero(2))]),
        Card::new_minion(next_id(), "Frostwolf Warlord", 5, 4, 4, vec![]),
        Card::new_minion(next_id(), "Stormpike Commando", 5, 4, 2, vec![CardEffect::Battlecry(BattlecryEffect::DealDamage(2))]),

        // 6+ cost minions
        Card::new_minion(next_id(), "Boulderfist Ogre", 6, 6, 7, vec![]),
        Card::new_minion(next_id(), "Lord of the Arena", 6, 6, 5, vec![CardEffect::Taunt]),
        Card::new_minion(next_id(), "Gurubashi Berserker", 5, 2, 7, vec![]),
        Card::new_minion(next_id(), "Sunwalker", 6, 3, 5, vec![CardEffect::Taunt, CardEffect::DivineShield]),

        // Spells
        Card::new_spell(next_id(), "Fireball", 4, SpellEffect::DealDamage(6)),
        Card::new_spell(next_id(), "Holy Light", 2, SpellEffect::HealHero(6)),
        Card::new_spell(next_id(), "Arcane Intellect", 3, SpellEffect::DrawCards(2)),
        Card::new_spell(next_id(), "Flamestrike", 7, SpellEffect::DealDamageAll(4)),
        Card::new_spell(next_id(), "Shield Block", 3, SpellEffect::GainArmor(5)),
        Card::new_spell(next_id(), "Mortal Strike", 4, SpellEffect::DealDamage(4)),
        Card::new_spell(next_id(), "Power Word: Shield", 1, SpellEffect::BuffMinion(0, 2)),
        Card::new_spell(next_id(), "Silence", 0, SpellEffect::Silence),
    ]
}

pub fn make_deck(size: usize) -> Vec<Card> {
    let mut pool = all_cards();
    let mut rng = thread_rng();
    pool.shuffle(&mut rng);
    pool.truncate(size);
    pool
}

pub fn make_balanced_deck() -> Vec<Card> {
    let all = all_cards();
    let mut deck = vec![];
    let mut rng = thread_rng();

    let mut low: Vec<&Card> = all.iter().filter(|c| c.cost <= 2).collect();
    let mut mid: Vec<&Card> = all.iter().filter(|c| c.cost == 3 || c.cost == 4).collect();
    let mut high: Vec<&Card> = all.iter().filter(|c| c.cost >= 5).collect();

    low.shuffle(&mut rng);
    mid.shuffle(&mut rng);
    high.shuffle(&mut rng);

    for c in low.iter().take(8) { deck.push((*c).clone()); }
    for c in mid.iter().take(12) { deck.push((*c).clone()); }
    for c in high.iter().take(10) { deck.push((*c).clone()); }

    deck.shuffle(&mut rng);

    // Re-assign unique IDs since cloning shares IDs
    let mut id = unsafe { NEXT_ID };
    for card in &mut deck {
        card.id = id;
        id += 1;
    }
    unsafe { NEXT_ID = id; }

    deck
}
